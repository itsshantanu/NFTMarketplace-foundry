# NFT Marketplace - Foundry Project

A decentralized NFT marketplace built with Solidity and tested using Foundry's comprehensive testing framework.

## 🏗️ Project Overview

This project implements a full-featured NFT marketplace with:
- **ERC721 NFT contracts** with built-in royalty support
- **ERC20 token integration** for marketplace payments
- **Platform fee system** for marketplace sustainability
- **Royalty distribution** to original creators
- **Comprehensive testing suite** with 4-layer testing architecture

## 📁 Project Structure

```
├── src/
│   ├── Marketplace.sol      # Main NFT marketplace contract
│   ├── ERC721.sol          # Custom NFT contract with royalties
│   ├── ERC20.sol           # Token contract for payments
│   └── interfaces/         # Contract interfaces
├── test/
│   ├── UnitTests.t.sol         # Component-level testing (27 tests)
│   ├── FuzzTests.t.sol         # Random input testing (12 tests)
│   ├── InvariantTests.t.sol    # System-wide properties (11 tests)
│   └── ForkedUnitTests.t.sol   # Real network testing (13 tests)
├── script/                 # Deployment and interaction scripts
└── docs/                   # Additional documentation
```

## 🧪 Four-Layer Testing Architecture

This project implements a comprehensive testing strategy with **63 total tests** across four specialized layers:

### 1. **Unit Tests** (`UnitTests.t.sol`)
- **Purpose**: Test individual contract components in isolation
- **Coverage**: 27 tests (24 passing, 3 failing)
- **Focus**: Basic functionality, edge cases, error conditions
- **Examples**: Token transfers, NFT minting, marketplace listings

### 2. **Fuzz Tests** (`FuzzTests.t.sol`)  
- **Purpose**: Property-based testing with thousands of random inputs
- **Coverage**: 12 tests (8 passing, 4 failing)
- **Focus**: Input validation, boundary discovery, property verification
- **Examples**: Random prices, user combinations, edge values

### 3. **Invariant Tests** (`InvariantTests.t.sol`)
- **Purpose**: System-wide property verification across transaction sequences
- **Coverage**: 11 tests (9 passing, 2 failing)
- **Focus**: Mathematical properties, economic rules, state consistency
- **Examples**: Token conservation, fee calculations, ownership integrity

### 4. **Forked Tests** (`ForkedUnitTests.t.sol`)
- **Purpose**: Test against real blockchain state and conditions
- **Coverage**: 13 tests (10 passing, 3 failing)
- **Focus**: Cross-chain compatibility, real token integration, gas optimization
- **Examples**: Testnet integration, whale interactions, network performance

## 🚀 Quick Start

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation
```bash
# Clone the repository
git clone https://github.com/itsshantanu/NFTMarketplace-foundry.git
cd NFTMarketplace-foundry

# Install dependencies
make install

# Build contracts
make build
```

### Testing

#### Run All Tests
```bash
# Complete test suite (recommended)
make test-all

# Or run all tests at once
forge test
```

#### Individual Test Types
```bash
# Unit Tests - Component testing
make test-unit

# Fuzz Tests - Random input testing  
make test-fuzz

# Invariant Tests - System property verification
make test-invariant

# Forked Tests - Real network conditions
make test-forked
```

#### Filtered Testing
```bash
# Only passing tests
make test-unit-passing
make test-fuzz-passing
make test-invariant-passing
make test-forked-passing

# Only failing tests (bug demonstrations)
make test-unit-failing
make test-fuzz-failing
make test-invariant-failing
make test-forked-failing

# Verbose output
make test-unit-verbose
make test-fuzz-verbose
make test-invariant-verbose
make test-forked-verbose
```

## 🐛 Known Issues

The testing framework intentionally exposes critical bugs in the marketplace:

### **Payment Logic Bug**
- **Issue**: Buyers pay more than the listed price
- **Expected**: Buyer pays only the NFT's listed price
- **Actual**: Buyer pays listed price + royalty + platform fee
- **Impact**: 7.5% overcharge (5% royalty + 2.5% platform fee)
- **Detected by**: All four test layers consistently

### **Economic Invariant Violations**
- **Issue**: Fee distribution doesn't match payment collection
- **Impact**: Economic inconsistencies in the marketplace
- **Detected by**: Invariant and fuzz tests

## 🔧 Configuration

### Environment Setup
Copy `.env.example` to `.env` and configure:

```bash
# Testnet RPC URLs (for forked testing)
MAINNET_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
POLYGON_RPC_URL=https://polygon-amoy.g.alchemy.com/v2/YOUR_API_KEY
ARBITRUM_RPC_URL=https://arb-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# Deployment settings
PRIVATE_KEY=your_private_key_here
```

### Forked Testing
To enable real network testing:
1. Get free API keys from [Alchemy](https://alchemy.com) or use public RPCs
2. Update RPC URLs in `.env`
3. Run `make test-forked`

## 📊 Test Results Summary

| Test Type | File | Passing | Failing | Total |
|-----------|------|---------|---------|-------|
| Unit Tests | `UnitTests.t.sol` | 24 | 3 | 27 |
| Fuzz Tests | `FuzzTests.t.sol` | 8 | 4 | 12 |
| Invariant Tests | `InvariantTests.t.sol` | 9 | 2 | 11 |
| Forked Tests | `ForkedUnitTests.t.sol` | 10 | 3 | 13 |
| **TOTAL** | | **51** | **12** | **63** |

## 🛠️ Development

### Contract Deployment
```bash
# Deploy to testnet
make deploy

# Deploy with custom RPC
forge script script/DeployMarket.s.sol --rpc-url $YOUR_RPC_URL --broadcast
```

### Adding Tests
1. **Unit Tests**: Add to `test/UnitTests.t.sol` for component testing
2. **Fuzz Tests**: Add to `test/FuzzTests.t.sol` for property-based testing
3. **Invariant Tests**: Add to `test/InvariantTests.t.sol` for system properties
4. **Forked Tests**: Add to `test/ForkedUnitTests.t.sol` for real network testing

## 📚 Documentation

- **[Complete Testing Framework](COMPLETE_TESTING_FRAMEWORK.md)** - Comprehensive testing overview
- **[Unit Tests Documentation](UNIT_TESTS.md)** - Detailed unit test guide
- **[Fuzz Tests Documentation](FUZZ_TESTS.md)** - Fuzz testing methodology
- **[Forked Tests Documentation](FORKED_TESTS.md)** - Real network testing guide

## 🔍 Key Features

### Smart Contracts
- **NFTMarket**: Core marketplace with listing/buying functionality
- **MyNFT**: ERC721 implementation with royalty support
- **MoonToken**: ERC20 token for marketplace payments

### Testing Features
- **Cross-validation**: Same bugs found across all test layers
- **Real Network Testing**: Testnet integration with actual tokens
- **Property-based Testing**: Thousands of random input combinations
- **Economic Validation**: Mathematical property verification
- **Gas Optimization**: Performance testing across networks

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add appropriate tests for new functionality
4. Ensure all tests pass: `make test-all`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Repository**: [GitHub](https://github.com/itsshantanu/NFTMarketplace-foundry)
- **Foundry Documentation**: [Book](https://book.getfoundry.sh/)
- **Solidity Documentation**: [Docs](https://docs.soliditylang.org/)

---

**Note**: This project includes intentional bugs for educational and testing demonstration purposes. The comprehensive testing framework successfully identifies these issues across all testing layers.
