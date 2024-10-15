use starknet::ContractAddress;

#[starknet::interface]
pub trait IFundable<TContractState> {
    fn distribute(ref self: TContractState, amount: u256, recipients: Array<ContractAddress>, token: ContractAddress);
    fn get_balance(self: @TContractState) -> felt252;
}

#[starknet::contract]
mod Fundable {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        balance: felt252,
    }

    #[abi(embed_v0)]
    impl FundableImpl of super::IFundable<ContractState> {
        fn distribute(ref self: ContractState, amount: u256, recipients: Array<ContractAddress>, token: ContractAddress) {
            let token = IERC20Dispatcher {contract_address: token};
            for i in 0..recipients.len() {
                token.transfer(*recipients[i], amount);
            }  
        }

        fn get_balance(self: @ContractState) -> felt252 {
            self.balance.read()
        }
    }
}
