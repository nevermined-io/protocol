[![banner](https://raw.githubusercontent.com/nevermined-io/assets/main/images/logo/banner_logo.png)](https://nevermined.io)

# Nevermined Smart Contracts v2

> 💧 Smart Contracts implementation of Nevermined in Solidity
> [nevermined.io](https://nevermined.io)

## Overview

Nevermined Smart Contracts form the core of the Nevermined protocol, enabling secure asset registration, access control, and payment management in a decentralized environment. This protocol facilitates the entire lifecycle of digital assets, from registration and pricing to access management and payment processing.

### Key Features

- **Asset Registration**: Register digital assets with customizable access plans
- **Agreement Management**: Create and manage agreements between parties with condition-based fulfillment
- **Payment Handling**: Secure escrow and distribution of payments
- **Access Control**: NFT-based credits system for managing access rights
- **Configurable Fees**: Network fee management for platform sustainability

## Architecture

The Nevermined Smart Contracts are organized around several core components:

### Core Components

1. **NVMConfig**
   - Central registry for roles, fees, and contract addresses
   - Manages access control and permissions
   - Stores configuration parameters

2. **AssetsRegistry**
   - Manages asset registration and metadata
   - Handles access plans and pricing configurations
   - Supports different pricing models (fixed price, fiat price, smart contract price)

3. **AgreementsStore**
   - Stores and tracks agreements between parties
   - Manages condition states and fulfillment
   - Provides agreement verification

4. **PaymentsVault**
   - Escrow for holding and releasing payments
   - Supports both native tokens and ERC20 tokens
   - Manages deposit and withdrawal permissions

5. **NFT1155Credits**
   - ERC1155-based NFT implementation for access rights
   - Supports different credit types (expirable, fixed, dynamic)
   - Manages minting and burning of access tokens

### Conditions System

The protocol uses a condition-based agreement system where specific conditions must be met before payments are released or access is granted:

- **LockPaymentCondition**: Handles locking payments in escrow
- **TransferCreditsCondition**: Manages the transfer of access credits
- **DistributePaymentsCondition**: Controls payment distribution to receivers

### Agreement Templates

- **FixedPaymentTemplate**: Template for agreements with fixed payment terms

## Setup and Installation

### Prerequisites

- Node.js (>= 18.x)
- Yarn

### Installation

```bash
# Clone the repository
git clone https://github.com/nevermined-io/contracts-exp.git
cd contracts-exp

# Install dependencies
yarn install
```

## Development Scripts

The project includes several scripts to help with development:

### Building and Compiling

```bash
# Clean the Hardhat environment
yarn clean

# Compile contracts
yarn compile
# or
yarn build
```

### Testing

```bash
# Run unit tests
yarn test

# Run integration tests
yarn test:integration

# Run tests with gas reporting
yarn test:gas

# Run test coverage
yarn coverage
```

### Local Development

```bash
# Start a local Hardhat node
yarn chain
```

### Code Quality

```bash
# Lint Solidity code
yarn lint

# Fix linting issues
yarn lint:fix

# Format code
yarn format

# Format Solidity code
yarn prettier:solidity

# Format TypeScript code
yarn prettier:ts

# Check code with Biome
yarn biome

# Fix code with Biome
yarn biome:fix
```

### Deployment

```bash
# Deploy contracts (general)
yarn deploy

# Deploy to local network
yarn deploy:local

# Deploy to Sepolia testnet
yarn deploy:sepolia
```

## Contract Interaction Flow

A typical interaction flow in the Nevermined protocol:

1. Asset owner registers an asset with pricing plans in the AssetsRegistry
2. Consumer creates an agreement using a template (e.g., FixedPaymentTemplate)
3. Payment is locked in the PaymentsVault (LockPaymentCondition)
4. Access credits are transferred to the consumer (TransferCreditsCondition)
5. Payments are distributed to receivers (DistributePaymentsCondition)

## License

```text
Copyright 2025 Nevermined AG

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
