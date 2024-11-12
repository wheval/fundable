'use client';

import { useState, useCallback } from 'react';
import { useAccount, useContract, useTransactionReceipt } from '@starknet-react/core';
import { useDropzone } from 'react-dropzone';
import Papa from 'papaparse';
import { ConnectWallet } from '@/components/ConnectWallet';
import { Contract, uint256 } from 'starknet';
import { validateDistribution } from '@/utils/validation';
import { toast } from 'react-hot-toast';
import { parseUnits } from 'ethers';

// ERC20 ABI - we only need the transfer function
const erc20ABI = [
  {
    members: [
      {
        name: "low",
        offset: 0,
        type: "felt"
      },
      {
        name: "high",
        offset: 1,
        type: "felt"
      }
    ],
    name: "Uint256",
    size: 2,
    type: "struct"
  },
  {
    inputs: [
      {
        name: "recipient",
        type: "felt"
      },
      {
        name: "amount",
        type: "Uint256"
      }
    ],
    name: "transfer",
    outputs: [
      {
        name: "success",
        type: "felt"
      }
    ],
    type: "function",
    state_mutability: "external"
  }
] as const;

interface Distribution {
  address: string;
  amount: string;
}

// Replace with your token contract address
const TOKEN_ADDRESS = '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d'; // Example: ETH token on testnet

export default function DistributePage() {
  const { address, status, account } = useAccount();
  const [distributions, setDistributions] = useState<Distribution[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [currentTxHash, setCurrentTxHash] = useState<string | undefined>();
  
  const { contract } = useContract({
    address: TOKEN_ADDRESS,
    abi: erc20ABI,
  });

  // Add transaction receipt hook
  const { data: receipt, isLoading: isWaitingForTx, status: receiptStatus, error: receiptError } = useTransactionReceipt({
    hash: currentTxHash,
    watch: true,
  });

  const onDrop = useCallback((acceptedFiles: File[]) => {
    const file = acceptedFiles[0];
    Papa.parse(file, {
      complete: (results) => {
        const parsedDistributions = results.data
          .filter((row: any) => row.length >= 2)
          .map((row: any) => ({
            address: row[0],
            amount: row[1],
          }));
        setDistributions(parsedDistributions);
      },
      header: false,
    });
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'text/csv': ['.csv'],
    },
    maxFiles: 1,
  });

  const addNewRow = () => {
    setDistributions([...distributions, { address: '', amount: '' }]);
  };

  const updateDistribution = (index: number, field: keyof Distribution, value: string) => {
    const newDistributions = [...distributions];
    newDistributions[index] = {
      ...newDistributions[index],
      [field]: value,
    };
    setDistributions(newDistributions);
  };

  const removeRow = (index: number) => {
    setDistributions(distributions.filter((_, i) => i !== index));
  };

  const handleDistribute = async () => {
    if (status !== 'connected' || !address || !account) {
      toast.error('Please connect your wallet first');
      return;
    }

    if (!contract) {
      toast.error('Contract not initialized');
      return;
    }

    if (distributions.length === 0) {
      toast.error('No distributions added');
      return;
    }

    // Check if there are any distributions
    const validationErrors: string[] = [];
    distributions.forEach((dist, index) => {
      const validation = validateDistribution(dist.address, dist.amount);
      if (!validation.isValid && validation.error) {
        validationErrors.push(`Row ${index + 1}: ${validation.error}`);
      }
    });

    if (validationErrors.length > 0) {
      toast.error(
        <div>
          Invalid distributions:
          <ul className="list-disc pl-4 mt-2">
            {validationErrors.map((error, i) => (
              <li key={i} className="text-sm">{error}</li>
            ))}
          </ul>
        </div>
      );
      return;
    }

    setIsLoading(true);
    let successCount = 0;
    let failureCount = 0;

    try {
      toast.loading(
        `Processing ${distributions.length} distributions...`, 
        { duration: Infinity }
      );

      for (const [index, dist] of distributions.entries()) {
        try {
          const amount = parseUnits(dist.amount, 18);
          const amountUint256 = uint256.bnToUint256(amount);

          
          const progressToast = toast.loading(
            `Processing ${index + 1}/${distributions.length}: ${dist.address.slice(0, 6)}...${dist.address.slice(-4)}`,
            { duration: Infinity }
          );

          // Create contract with signer
          const contractWithSigner = new Contract(
            erc20ABI,
            contract.address,
            account
          );

          // Execute transfer
          const tx = await contractWithSigner.transfer(
            dist.address,
            amountUint256
          );

          // Set current transaction hash for monitoring
          setCurrentTxHash(tx.transaction_hash);

          // Wait for transaction receipt using the hook

          if (receiptStatus === 'success') {
            successCount++;
            toast.success(
              `Transfer confirmed for ${dist.address.slice(0, 6)}...${dist.address.slice(-4)}`
            );
          } else if (receiptStatus === 'pending') {
            // Wait for the transaction to be finalized
            toast.loading(
              `Waiting for transaction to be finalized...`,
              { duration: Infinity }
            );
          } else if (receiptStatus === 'error') {
            failureCount++;
            toast.error(
              `Transfer reverted for ${dist.address.slice(0, 6)}...${dist.address.slice(-4)}${
                receiptError ? `: ${receiptError}` : ''
              }`
            );
          }

          toast.dismiss(progressToast);
          setCurrentTxHash(undefined); // Reset transaction hash

        } catch (error) {
          failureCount++;
          console.error('Error processing distribution to', dist.address, ':', error);
          toast.error(
            `Failed to transfer to ${dist.address.slice(0, 6)}...${dist.address.slice(-4)}: ${
              error instanceof Error ? error.message : 'Unknown error'
            }`
          );
        }
      }

      // Show final summary
      if (successCount > 0) {
        toast.success(`Successfully processed ${successCount} distributions`);
      }
      if (failureCount > 0) {
        toast.error(`Failed to process ${failureCount} distributions`);
      }

    } catch (error) {
      console.error('Distribution process failed:', error);
      toast.error('Distribution process failed');
    } finally {
      setIsLoading(false);
      setCurrentTxHash(undefined);
      if (failureCount === 0 && successCount > 0) {
        setDistributions([]);
      }
    }
  };

  // Show connect wallet message if not connected
  if (status !== 'connected' || !address) {
    return (
      <div className="container mx-auto px-4 py-16">
        <div className="text-center">
          <h1 className="text-3xl font-bold mb-8">Token Distribution</h1>
          <div className="p-8 rounded-lg bg-starknet-purple bg-opacity-20">
            <p className="text-starknet-cyan mb-4">
              Please connect your wallet to use the distribution feature
            </p>
            <ConnectWallet />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-16">
      <h1 className="text-3xl font-bold mb-8">Token Distribution</h1>

      {/* CSV Upload Section */}
      <div
        {...getRootProps()}
        className={`border-2 border-starknet-cyan rounded-lg p-8 mb-8 text-center cursor-pointer
          ${isDragActive ? 'bg-starknet-purple bg-opacity-20' : ''}`}
      >
        <input {...getInputProps()} />
        {isDragActive ? (
          <p>Drop the CSV file here...</p>
        ) : (
          <p>Drag and drop a CSV file here, or click to select a file</p>
        )}
        <p className="text-sm text-gray-400 mt-2">
          CSV format: address,amount (one per line)
        </p>
      </div>

      {/* Manual Input Section */}
      <div className="mb-8">
        <div className="flex justify-between mb-4">
          <h2 className="text-xl font-semibold">Manual Input</h2>
          <button
            onClick={addNewRow}
            className="px-4 py-2 bg-starknet-cyan text-starknet-navy rounded-lg font-semibold hover:bg-opacity-90 transition-all"
          >
            Add Row
          </button>
        </div>

        {/* Distribution List */}
        <div className="space-y-4">
          {distributions.map((dist, index) => (
            <div key={index} className="flex gap-4">
              <input
                type="text"
                placeholder="Address"
                value={dist.address}
                onChange={(e) => updateDistribution(index, 'address', e.target.value)}
                className="flex-1 bg-starknet-purple bg-opacity-50 rounded-lg px-4 py-2 text-white placeholder-gray-400"
              />
              <input
                type="text"
                placeholder="Amount"
                value={dist.amount}
                onChange={(e) => updateDistribution(index, 'amount', e.target.value)}
                className="w-32 bg-starknet-purple bg-opacity-50 rounded-lg px-4 py-2 text-white placeholder-gray-400"
              />
              <button
                onClick={() => removeRow(index)}
                className="px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-opacity-80 transition-all"
              >
                Remove
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* Distribution Button */}
      <button
        onClick={handleDistribute}
        disabled={isLoading || distributions.length === 0}
        className={`w-full px-6 py-3 bg-starknet-cyan text-starknet-navy rounded-lg font-semibold 
          ${isLoading || distributions.length === 0 
            ? 'opacity-50 cursor-not-allowed' 
            : 'hover:bg-opacity-90'} 
          transition-all`}
      >
        {isLoading ? 'Processing...' : 'Distribute Tokens'}
      </button>
    </div>
  );
} 