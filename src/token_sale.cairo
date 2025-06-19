#[starknet::contract]
pub mod TokenSale {
use UpgradeableComponent::InternalTrait;
use starknet::{ContractAddress, ClassHash, get_contract_address, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry};
    use crate::interfaces::itoken_sale::ITokenSale;
    use crate::interfaces::ierc20::{IERC20TokenDispatcher, IERC20TokenDispatcherTrait};
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl OwnableComponentImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    pub struct Storage {
        accepted_payment_token: ContractAddress,
        token_price: Map<ContractAddress, u256>,
        owner: ContractAddress,
        tokens_available_for_sale: Map<ContractAddress, u256>,

        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,

        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, accepted_payment_token: ContractAddress) {
        // This function should be called at construction time as stated in open zeppelin repo.
        self.ownable.initializer(owner);
        self.accepted_payment_token.write(accepted_payment_token);
    }

    #[abi(embed_v0)]
    impl TokenSaleImpl of ITokenSale<ContractState> {
        fn get_accepted_payment_token(self: @ContractState) -> ContractAddress {
            self.accepted_payment_token.read()
        }

        fn check_available_token(self: @ContractState, token_address: ContractAddress) -> u256 {
            let token = IERC20TokenDispatcher {contract_address: token_address};
            let address = get_contract_address();
            token.balance_of(address)
        }

        fn deposit_token(ref self: ContractState, token_address: ContractAddress, amount: u256, token_price: u256) {
            let caller = get_caller_address();
            let this_contract = get_contract_address();
            
            // Removed the manual assertion and use the OZ ownable assertion
            self.ownable.assert_only_owner();

            let token = IERC20TokenDispatcher {contract_address: self.accepted_payment_token.read()};
            assert(token.balance_of(caller) > 0, 'insufficient balance');

            let transfer = token.transfer_from(caller, this_contract, amount);
            assert(transfer, 'transfer failed');

            self.tokens_available_for_sale.entry(token_address).write(amount);
            self.token_price.entry(token_address).write(token_price);
        }

        fn buy_token(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            let for_sale_amount = self.tokens_available_for_sale.entry(token_address).read();
            assert(for_sale_amount == amount, 'amount must be exact');

            let buyer = get_caller_address();

            let payment_token = IERC20TokenDispatcher {contract_address: self.accepted_payment_token.read()};
            let token_to_buy = IERC20TokenDispatcher {contract_address: token_address};

            let buyer_balance = payment_token.balance_of(buyer);
            let buying_price = self.token_price.entry(token_address).read();

            assert(buyer_balance >= buying_price, 'Insufficient balance');

            payment_token.transfer_from(buyer, get_contract_address(), buying_price);
            let total_contract_balance = self.tokens_available_for_sale.entry(token_address).read();
            token_to_buy.transfer(buyer, total_contract_balance);

        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // assert(get_caller_address() == self.owner.read(), 'Unauthorized caller');
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}