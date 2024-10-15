use starknet::ContractAddress;

use snforge_std::{declare, ContractClassTrait};
use openzeppelin::token::erc20::erc20::

use fundable::IFundableDispatcher;
use fundable::IFundableDispatcherTrait;
use fundable::IFundableSafeDispatcher;

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
fn test_increase_balance() {
    let contract_address = deploy_contract("Fundable");

    let dispatcher = IFundableDispatcher { contract_address };

    let recipients = create_address(2);


    let balance_before = dispatcher.distribute(42, recipients, contract_address);
}

fn create_address(number: u8) -> ContractAddress[] {
    let mut addresses = ArrayTrait::new();
    for i in 0..number {
        addresses.push(ContractAddress::new(i));
    }
    addresses
}
