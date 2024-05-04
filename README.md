# Mobile_Market

## Overview

The `mobile_market` on the Sui blockchain platform is designed to facilitate direct transactions between farmers and consumers, bypassing traditional market intermediaries. This module enables farmers to list products, manage bids, and handle payments securely within a decentralized framework, thus enhancing transparency and efficiency.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Run a local network](#run-a-local-network)
- [Configure connectivity to a local node](#configure-connectivity-to-a-local-node)
- [Create addresses](#create-addresses)
- [Get localnet SUI tokens](#get-localnet-SUI-tokens)
- [Build and publish a smart contract](#build-and-publish-a-smart-contract)
  - [Build package](#build-package)
  - [Publish package](#publish-package)
- [Structs](#structs)
  - [Farmer](#farmer)
  - [ProductRecord](#productrecord)
  - [FarmerCap](#farmercap)
- [Core Functionalities](#core-functionalities)
  - [Adding Products](#adding-products-)
  - [Bidding for Products](#bidding-for-products-)
  - [Accepting Bids](#accepting-bids-)
  - [Resolving Disputes](#resolving-disputes-)
  - [Releasing Payments](#releasing-payments-)
  - [Adding Funds to Escrow](#adding-funds-to-escrow-)
  - [Withdrawing Funds from Escrow](#withdrawing-funds-from-escrow-)
  - [Updating Product Details](#updating-product-details-)
  - [Rating Farmers](#rating-farmers-)



## Prerequisites
1. Install dependencies by running the following commands:
   
   - `sudo apt update`
   
   - `sudo apt install curl git-all cmake gcc libssl-dev pkg-config libclang-dev libpq-dev build-essential -y`

2. Install Rust and Cargo
   
   - `curl https://sh.rustup.rs -sSf | sh`
   
   - source "$HOME/.cargo/env"

3. Install Sui Binaries
   
   - run the command `chmod u+x sui-binaries.sh` to make the file an executable
   
   execute the installation file by running
   
   - `./sui-binaries.sh "v1.21.0" "devnet" "ubuntu-x86_64"` for Debian/Ubuntu Linux users
   
   - `./sui-binaries.sh "v1.21.0" "devnet" "macos-x86_64"` for Mac OS users with Intel based CPUs
   
   - `./sui-binaries.sh "v1.21.0" "devnet" "macos-arm64"` for Silicon based Mac 

For detailed installation instructions, refer to the [Installation and Deployment](#installation-and-deployment) section in the provided documentation.

## Installation

1. Clone the repository:
   ```sh
   git clone https://github.com/Ankodudu/Mobile-Market.git
   ```
2. Navigate to the working directory
   ```sh
   cd mobile_market
   ```
## Run a local network
To run a local network with a pre-built binary (recommended way), run this command:
```
RUST_LOG="off,sui_node=info" sui-test-validator
```
## Configure connectivity to a local node
Once the local node is running (using `sui-test-validator`), you should the url of a local node - `http://127.0.0.1:9000` (or similar).
Also, another url in the output is the url of a local faucet - `http://127.0.0.1:9123`.

Next, we need to configure a local node. To initiate the configuration process, run this command in the terminal:
```
sui client active-address
```
The prompt should tell you that there is no configuration found:
```
Config file ["/home/codespace/.sui/sui_config/client.yaml"] doesn't exist, do you want to connect to a Sui Full node server [y/N]?
```
Type `y` and in the following prompts provide a full node url `http://127.0.0.1:9000` and a name for the config, for example, `localnet`.

On the last prompt you will be asked which key scheme to use, just pick the first one (`0` for `ed25519`).

After this, you should see the ouput with the wallet address and a mnemonic phrase to recover this wallet. You can save so later you can import this wallet into SUI Wallet.

Additionally, you can create more addresses and to do so, follow the next section - `Create addresses`.


### Create addresses
For this tutorial we need two separate addresses. To create an address run this command in the terminal:
```
sui client new-address ed25519
```
where:
- `ed25519` is the key scheme (other available options are: `ed25519`, `secp256k1`, `secp256r1`)

And the output should be similar to this:
```
╭─────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Created new keypair and saved it to keystore.                                                   │
├────────────────┬────────────────────────────────────────────────────────────────────────────────┤
│ address        │ 0x05db1e318f1e4bc19eb3f2fa407b3ebe1e7c3cd8147665aacf2595201f731519             │
│ keyScheme      │ ed25519                                                                        │
│ recoveryPhrase │ lava perfect chef million beef mean drama guide achieve garden umbrella second │
╰────────────────┴────────────────────────────────────────────────────────────────────────────────╯
```
Use `recoveryPhrase` words to import the address to the wallet app.


### Get localnet SUI tokens
```
curl --location --request POST 'http://127.0.0.1:9123/gas' --header 'Content-Type: application/json' \
--data-raw '{
    "FixedAmountRequest": {
        "recipient": "<ADDRESS>"
    }
}'
```
`<ADDRESS>` - replace this by the output of this command that returns the active address:
```
sui client active-address
```

You can switch to another address by running this command:
```
sui client switch --address <ADDRESS>
```

## Build and publish a smart contract

### Build package
To build tha package, you should run this command:
```
sui move build
```

If the package is built successfully, the next step is to publish the package:
### Publish package
```
sui client publish --gas-budget 100000000 --json
` - `sui client publish --gas-budget 1000000000`
```
## Structs

### Farmer 🌾

```
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
```

### ProductRecord 📄

```
struct FarmerCap has key {
  id: UID,
  farmer_id: ID,
}
```

## Core Functionalities

### adding-products 🌾

- **Parameters**:
  - name: `String`
  - bio: `String`
  - category: `String`
  - price: `u64`
  - status: `String`
  - ctx: `&mut TxContext`

- **Description**: Allows farmers to list their products on the marketplace, setting the price, description, and other relevant details.

- **Errors**:
  - **EInvalidProduct**: if the product details provided are not valid.

### bidding-for-products 🤝

- **Parameters**:
  - product_id: `UID`
  - ctx: `&mut TxContext`

- **Description**: Enables consumers to place bids on listed products, which farmers can later accept.

- **Errors**:
  - **EInvalidBid**: if the bid is made on an already sold or unavailable product.

### accepting-bids ✔️

- **Parameters**:
  - product_id: `UID`
  - ctx: `&mut TxContext`

- **Description**: Allows farmers to accept bids from consumers, initiating the transaction process.

- **Errors**:
  - **ENotConsumer**: if the action is attempted by someone other than the consumer who placed the bid.

### resolving-disputes ⚖️

- **Parameters**:
  - product_id: `UID`
  - resolved: `bool`
  - ctx: `&mut TxContext`

- **Description**: Handles disputes that may arise between farmers and consumers during the transaction process.

- **Errors**:
  - **EDispute**: if there is no ongoing dispute to resolve.

### releasing-payments 💸

- **Parameters**:
  - product_id: `UID`
  - ctx: `&mut TxContext`

- **Description**: Facilitates the release of funds from escrow to the farmer once all conditions of the transaction are met.

- **Errors**:
  - **EInsufficientEscrow**: if the funds in escrow are not sufficient to cover the transaction.

### adding-funds-to-escrow 💰

- **Parameters**:
  - product_id: `UID`
  - amount: `Coin<SUI>`
  - ctx: `&mut TxContext`

- **Description**: Allows additional funds to be added to escrow for a product, ensuring that sufficient funds are available to complete the transaction.

- **Errors**:
  - **EInvalidProduct**: if the product does not exist or is already sold.

### withdrawing-funds-from-escrow 🏦

- **Parameters**:
  - product_id: `UID`
  - amount: `u64`
  - ctx: `&mut TxContext`

- **Description**: Enables farmers to withdraw funds from escrow, typically after a transaction is cancelled or resolved.

- **Errors**:
  - **EInvalidWithdrawal**: if the withdrawal request exceeds the amount available in escrow.

### updating-product-details 📝

- **Parameters**:
  - product_id: `UID`
  - new_details: `String` (new price, description, etc.)
  - ctx: `&mut TxContext`

- **Description**: Allows farmers to update details about their products, such as price, quantity, or description.

- **Errors**:
  - **EInvalidProduct**: if the product does not exist or the updates are invalid.

### rating-farmers ⭐

- **Parameters**:
  - farmer_id: `UID`
  - rating: `u64`
  - ctx: `&mut TxContext`

- **Description**: Enables consumers to rate farmers after a transaction, influencing the farmer's reputation on the platform.

- **Errors**:
  - **ENotConsumer**: if the rater is not a consumer who has engaged with the farmer.

