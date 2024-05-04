module MobileMarket::market {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext, sender};
    use sui::table::{Self, Table};
    
    use std::option::{Option, none, some, is_some, contains, borrow};
    use std::string::{String};
    use std::vector::{Self};
    
    // Errors
    const ERROR_WORK_NOT_SUBMIT: u64 = 1;
    const EInvalidProduct: u64 = 2;
    const ERROR_WRONG_ADDRESS: u64 = 3;
    const ERROR_INSUFFCIENT_FUNDS: u64 = 4;
    const ENotConsumer: u64 = 5;
    const EInvalidWithdrawal: u64 = 6;
    const EInsufficientEscrow: u64 = 7;
    const ERROR_INVALID_CAP :u64 = 8;
    const ERROR_FARM_CLOSED: u64 = 9;
    const ERROR_INVALID_SKILL: u64 = 10;
    
    // Struct definitions

    // Farmer struct
    struct Farmer has key, store {
        id: UID,
        farmer: address,
        name: String,
        bio: String,
        category: String,
        price: u64,
        escrow: Balance<SUI>,
        persons: Table<address, Person>,
        dispute: bool,
        rating: Option<u64>,
        status: bool,
        consumer: Option<address>,
        productSold: bool,
    }

    // struct that represent Farmer Capability
    struct FarmerCap has key {
        id: UID,
        farmer_id: ID,
    }

    struct Person has key, store {
        id: UID,
        farm_id: ID,
        owner: address,
        description: String,
        skills: vector<String>
    }
    
    // ProductRecord Struct
    struct ProductRecord has key, store {
        id: UID,
        farmer: address,
    }
    
    // Accessors
    public entry fun get_product_description(product: &Farmer): String {
        product.bio
    }
    
    public entry fun get_product_price(product: &Farmer): u64 {
        product.price
    }

    public entry fun get_product_status(product: &Farmer): bool {
        product.status
    }
    
    // Public Entry functions
    
    public fun new(name: String, bio: String, category: String, price: u64, status: String, ctx: &mut TxContext) : FarmerCap {
        let product_id = object::new(ctx);
        let inner_ = object::uid_to_inner(&product_id);
        transfer::share_object(Farmer {
            id: product_id,
            name: name,
            farmer: tx_context::sender(ctx),
            consumer: none(),
            bio: bio,
            category: category,
            rating: none(),
            status: false,
            price: price,
            escrow: balance::zero(),
            persons: table::new(ctx),
            productSold: false,
            dispute: false,
        });
        FarmerCap{
            id: object::new(ctx),
            farmer_id: inner_
        }   
    }

      // Users should create new worker for bid 
    public fun new_worker(farm: ID, description_: String, ctx: &mut TxContext) : Person {
        let worker = Person {
            id: object::new(ctx),
            farm_id: farm,
            owner: sender(ctx),
            description: description_,
            skills: vector::empty()
        };
        worker
    }
    // users can set new skills
    public fun add_skill(self: &mut Person, skill: String) {
        assert!(!vector::contains(&self.skills, &skill), ERROR_INVALID_SKILL);
        vector::push_back(&mut self.skills, skill);
    }
    // users can bid to works
    public fun bid_work(farm: &mut Farmer, worker: Person, ctx: &mut TxContext) {
        assert!(!farm.dispute, ERROR_FARM_CLOSED);
        table::add(&mut farm.persons, sender(ctx), worker);
    }
    // Raise a complain
    public entry fun dispute_product(cap: &FarmerCap, product: &mut Farmer) {
        assert!(cap.farmer_id == object::id(product), ERROR_INVALID_CAP);
        product.dispute = true;
    }

     // farmwork owner should choose worker and send to worker object to choosen.
    public fun choose(cap: &FarmerCap, farm: &mut Farmer, coin: Coin<SUI>, choosen: address) : Person {
        assert!(cap.farmer_id == object::id(farm), ERROR_INVALID_CAP);
        assert!(coin::value(&coin) >= farm.price, ERROR_INSUFFCIENT_FUNDS);

        let worker = table::remove(&mut farm.persons, choosen);
        let balance_ = coin::into_balance(coin);
        // submit the worker balance 
        balance::join(&mut farm.escrow, balance_);
        // farm closed. 
        farm.productSold = true;
        // set the worker address 
        farm.consumer = some(choosen);
        worker
    }

    public fun submit_work(self: &mut Farmer, ctx: &mut TxContext) {
        assert!(*borrow(&self.consumer) == sender(ctx), ERROR_WRONG_ADDRESS);
        self.status = true;
    }

    public fun confirm_work(cap: &FarmerCap, self: &mut Farmer, ctx: &mut TxContext) {
        assert!(cap.farmer_id == object::id(self), ERROR_INVALID_CAP);
        assert!(self.status, ERROR_WORK_NOT_SUBMIT);
        
        let balance_ = balance::withdraw_all(&mut self.escrow);
        let coin_ = coin::from_balance(balance_, ctx);
        
        transfer::public_transfer(coin_, *borrow(&self.consumer));
    }

    // Add more cash to escrow
    public entry fun add_to_escrow(product: &mut Farmer, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == product.farmer, ENotConsumer);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut product.escrow, added_balance);
    }

    // Withdraw funds from escrow
    public entry fun withdraw_from_escrow(cap: &FarmerCap, product: &mut Farmer, amount: u64, ctx: &mut TxContext) {
        assert!(cap.farmer_id == object::id(product), ERROR_INVALID_CAP);
        assert!(tx_context::sender(ctx) == product.farmer, ENotConsumer);
        assert!(product.productSold == false, EInvalidWithdrawal);
        let escrow_amount = balance::value(&product.escrow);
        assert!(escrow_amount >= amount, EInsufficientEscrow);
        let escrow_coin = coin::take(&mut product.escrow, amount, ctx);
        transfer::public_transfer(escrow_coin, tx_context::sender(ctx));
    }
    
    // Update the product category
    public entry fun update_product_category(cap: &FarmerCap, product: &mut Farmer, category: String, ctx: &mut TxContext) {
        assert!(cap.farmer_id == object::id(product), ERROR_INVALID_CAP);
        assert!(product.farmer == tx_context::sender(ctx), ENotConsumer);
        product.category = category;
    }
    
    // Update the product description
    public entry fun update_product_description(cap: &FarmerCap, product: &mut Farmer, bio: String, ctx: &mut TxContext) {
        assert!(cap.farmer_id == object::id(product), ERROR_INVALID_CAP);
        assert!(product.farmer == tx_context::sender(ctx), ENotConsumer);
        product.bio = bio;
    }
    
    // Update the product price
    public entry fun update_product_price(cap: &FarmerCap, product: &mut Farmer, price: u64, ctx: &mut TxContext) {
        assert!(cap.farmer_id == object::id(product), ERROR_INVALID_CAP);
        assert!(product.farmer == tx_context::sender(ctx), ENotConsumer);
        product.price = price;
    }
    
    // Rate the farmer
    public entry fun rate_farmer(product: &mut Farmer, rating: u64, ctx: &mut TxContext) {
        assert!(contains(&product.consumer, &tx_context::sender(ctx)), EInvalidProduct);
        product.rating = some(rating);
    }

}