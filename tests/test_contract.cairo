use starknet::ContractAddress;
use token_sale::interfaces::itoken_sale::{ITokenSaleDispatcher, ITokenSaleDispatcherTrait};
use starknet::contract_address::contract_address_const;
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

fn deploy_contract(name: ByteArray, owner: ContractAddress, accepted_payment_token: ContractAddress) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let mut constructor_data = ArrayTrait::new();
    constructor_data.append(owner.into());
    constructor_data.append(accepted_payment_token.into());

    let (contract_address, _) = contract.deploy(@constructor_data).unwrap();
    contract_address
}

// fn deploy_mock_token(name: ByteArray, initial_supply: u256, recipient: ContractAddress) -> ContractAddress {
//     let contract = declare(name).unwrap().contract_class();
//     let mut constructor_calldata = ArrayTrait::<felt252>::new();

//     // Deconstruct the u256 into its low and high parts
//     constructor_calldata.append(initial_supply.low.into());
//     constructor_calldata.append(initial_supply.high.into());

//      // Append the recipient
//      constructor_calldata.append(recipient.into());
    
//      let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
//      contract_address
// }

fn deploy_mock_token(
    name: felt252, 
    symbol: felt252,
    initial_supply: u256, 
    recipient: ContractAddress
) -> ContractAddress {
    // 2. Declare the mock token's artifact name
    let contract = declare("MockERC20Token").unwrap().contract_class(); 
    let mut constructor_calldata = ArrayTrait::<felt252>::new();

    // 3. Append ALL constructor args in the correct order (name, symbol, supply, recipient)
    constructor_calldata.append(name);
    constructor_calldata.append(symbol);
    constructor_calldata.append(initial_supply.low.into());
    constructor_calldata.append(initial_supply.high.into());
    constructor_calldata.append(recipient.into());
    
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

#[test]
fn test_constructor() {
    let owner: ContractAddress = contract_address_const::<0x123456711>();
    let accepted_payment_token: ContractAddress = contract_address_const::<0x123456789>();

    let contract_address = deploy_contract("TokenSale", owner, accepted_payment_token);

    let token_sale = ITokenSaleDispatcher { contract_address };

    // Test that the owner and accepted token are initialized correctly
    let ownable = IOwnableDispatcher {contract_address};
    
    assert_eq!(token_sale.get_accepted_payment_token(), accepted_payment_token);
    assert_eq!(ownable.owner(), owner);
}

#[test]
fn test_check_available_token() {
    let owner: ContractAddress = contract_address_const::<0x123456711>();
    let accepted_payment_token: ContractAddress = contract_address_const::<0x123456789>();

    let test_token = deploy_mock_token('Hameed', 'HMD', 10000_u256, owner);

    let contract_address = deploy_contract("TokenSale", owner, accepted_payment_token);

    let token_sale = ITokenSaleDispatcher { contract_address };

    assert_eq!(token_sale.check_available_token(test_token), 0_u256);
}