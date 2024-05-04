module MobileMarket::market {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    
    use std::option::{Option, none, some, is_some, contains, borrow};
    use std::string::{String};
    
    // Errors
    const EInvalidBid: u64 = 1;
    const EInvalidProduct: u64 = 2;
    const EDispute: u64 = 3;
    const EAlreadyResolved: u64 = 4;
    const ENotConsumer: u64 = 5;
    const EInvalidWithdrawal: u64 = 6;
    const EInsufficientEscrow: u64 = 7;
     const ERROR_INVALID_CAP :u64 = 8;
    
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
        dispute: bool,
        rating: Option<u64>,
        status: String,
        consumer: Option<address>,
        productSold: bool,
    }

    // struct that represent Farmer Capability
    struct FarmerCap has key {
        id: UID,
        farmer_id: ID,
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

    public entry fun get_product_status(product: &Farmer): String {
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
            status: status,
            price: price,
            escrow: balance::zero(),
            productSold: false,
            dispute: false,
        });
        FarmerCap{
            id: object::new(ctx),
            farmer_id: inner_
        }   
    }

    // Bid for a Product
    public entry fun product_bid(product: &mut Farmer, ctx: &mut TxContext) {
        assert!(!is_some(&product.consumer), EInvalidBid);
        product.consumer = some(tx_context::sender(ctx));
    }
    
    // Accept a bid(Farmer)
    public entry fun accept_bid(product: &mut Farmer, ctx: &mut TxContext) {
        assert!(product.farmer == tx_context::sender(ctx), ENotConsumer);
        assert!(is_some(&product.consumer), EInvalidBid);
        let _consumer = *borrow(&product.consumer);
        product.consumer = none();
        product.productSold = true;
    }
    

    // Mark product as sold
    public entry fun mark_prroduct_sold(product: &mut Farmer, ctx: &mut TxContext){
        assert!(contains(&product.consumer, &tx_context::sender(ctx)), EInvalidProduct);

        product.productSold = true;
    }
    
    // Raise a complain
    public entry fun dispute_product(product: &mut Farmer, ctx: &mut TxContext) {
        assert!(product.farmer == tx_context::sender(ctx), EDispute);
        product.dispute = true;
    }

    // Resolve dispute if any between farmer and consumer
    public entry fun resolve_dispute(product: &mut Farmer, resolved: bool, ctx: &mut TxContext) {
        assert!(product.farmer == tx_context::sender(ctx), EDispute);
        assert!(product.dispute, EAlreadyResolved);
        assert!(is_some(&product.consumer), EInvalidBid);
        let escrow_amount = balance::value(&product.escrow);
        let escrow_coin = coin::take(&mut product.escrow, escrow_amount, ctx);
        if (resolved) {
            let consumer = *borrow(&product.consumer);
            // Transfer funds to the consumer
            transfer::public_transfer(escrow_coin, consumer);
        } else {
            // Refund funds to the farmer
            transfer::public_transfer(escrow_coin, product.farmer);
        };
        
        // Reset product state
        product.consumer = none();
        product.productSold = false;
        product.dispute = false;
    }

    // Release Funds to the farmer
    public entry fun release_payment(product: &mut Farmer, ctx: &mut TxContext) {
        assert!(product.farmer == tx_context::sender(ctx), ENotConsumer);
        assert!(product.productSold && !product.dispute, EInvalidProduct);
        assert!(is_some(&product.consumer), EInvalidBid);

        let farmer = *borrow(&product.consumer);
        let escrow_amount = balance::value(&product.escrow);
        assert!(escrow_amount > 0, EInsufficientEscrow);
        let escrow_coin = coin::take(&mut product.escrow, escrow_amount, ctx);
        // Transfer funds to the farmer
        transfer::public_transfer(escrow_coin, farmer);

        // Cretae a new product record
        let productRecord = ProductRecord {
            id: object::new(ctx),
            farmer: product.farmer,
        };

        // Change access control to the product record
        transfer::public_transfer(productRecord, tx_context::sender(ctx));

        // Reset product state
        product.consumer = none();
        product.productSold = true;
        product.dispute = false;
        
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

    // Update the product status
    public entry fun update_product_status(cap: &FarmerCap, product: &mut Farmer, status: String, ctx: &mut TxContext) {
        assert!(cap.farmer_id == object::id(product), ERROR_INVALID_CAP);
        assert!(product.farmer == tx_context::sender(ctx), ENotConsumer);
        product.status = status;
    }

    // Rate the farmer
    public entry fun rate_farmer(product: &mut Farmer, rating: u64, ctx: &mut TxContext) {
        assert!(contains(&product.consumer, &tx_context::sender(ctx)), EInvalidProduct);
        product.rating = some(rating);
    }

}