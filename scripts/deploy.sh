#!/bin/bash

# Configuration
ACCOUNT_NAME="my_account"  # Replace with your account name
NETWORK="sepolia"         # Replace with your target network (sepolia, mainnet, etc.)
CLASS_HASH=""            # Replace with your contract's class hash after declaration
PROTOCOL_OWNER=""        # Replace with the protocol owner address

# Check if sncast is installed
if ! command -v sncast &> /dev/null; then
    echo "Error: sncast is not installed. Please install Starknet Foundry first."
    exit 1
fi

# Validate required parameters
if [ -z "$CLASS_HASH" ]; then
    echo "Error: CLASS_HASH is not set. Please set it in the script."
    exit 1
fi

if [ -z "$PROTOCOL_OWNER" ]; then
    echo "Error: PROTOCOL_OWNER is not set. Please set it in the script."
    exit 1
fi

# Deploy the contract
echo "Deploying contract with class hash $CLASS_HASH on $NETWORK..."
sncast --account $ACCOUNT_NAME \
    deploy \
    --network $NETWORK \
    --class-hash $CLASS_HASH \
    --constructor-calldata $PROTOCOL_OWNER

# Check if the deployment was successful
if [ $? -eq 0 ]; then
    echo "Contract deployment completed successfully!"
else
    echo "Error: Contract deployment failed."
    exit 1
fi 