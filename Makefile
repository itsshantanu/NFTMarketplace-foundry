SHELL := /bin/bash

# Makefile

.PHONY: install build deploy test test-all test-invariant test-invariant-verbose test-invariant-passing test-invariant-failing test-fuzz test-fuzz-verbose test-fuzz-passing test-fuzz-failing test-unit test-unit-verbose test-unit-passing test-unit-failing test-forked test-forked-verbose test-forked-passing test-forked-failing

install:
	@echo "Installing dependencies..."
	forge install

build:
	@echo "Building project..."
	forge build

deploy: install build
	@echo "Deploying contract..."
	forge script script/DeployMarket.s.sol --rpc-url=$(BUILDBEAR_RPC_URL) --broadcast --mnemonics="$(MNEMONIC)" --legacy --slow

test:
	@echo "Running all tests..."
	forge test

test-all:
	@echo "Running complete test suite (Unit → Fuzz → Invariant → Forked)..."
	@echo "========================================="
	@echo "1. Running Unit Tests..."
	@make test-unit-passing
	@echo ""
	@echo "2. Running Fuzz Tests..."
	@make test-fuzz-passing  
	@echo ""
	@echo "3. Running Invariant Tests..."
	@make test-invariant-passing
	@echo ""
	@echo "4. Running Forked Tests..."
	@make test-forked-passing
	@echo ""
	@echo "========================================="
	@echo "✅ Complete test suite finished!"
	@echo "Note: Use 'make test-*-failing' commands to see bug demonstrations"

test-invariant:
	@echo "Running invariant tests (all passing and failing)..."
	forge test --match-contract InvariantTests -vv

test-invariant-verbose:
	@echo "Running invariant tests with detailed output..."
	forge test --match-contract InvariantTests -vvv

test-invariant-passing:
	@echo "Running only passing invariant tests..."
	forge test --match-contract InvariantTests --match-test "invariant_(?!.*buyersOnlyPayListedPrice|.*sellersReceiveCorrectAmount|.*economicConsistency)" -v

test-invariant-failing:
	@echo "Running only failing invariant tests (bug demonstrations)..."
	forge test --match-contract InvariantTests --match-test "(buyersOnlyPayListedPrice|sellersReceiveCorrectAmount|economicConsistency|Bug)" -vv

test-fuzz:
	@echo "Running all fuzz tests (both passing and failing)..."
	forge test --match-contract FuzzTests -vv

test-fuzz-verbose:
	@echo "Running fuzz tests with detailed output..."
	forge test --match-contract FuzzTests -vvv

test-fuzz-passing:
	@echo "Running only passing fuzz tests..."
	forge test --match-contract FuzzTests --match-test "testFuzz_(MintNFT|ListNFT|Platform|Token|Multiple|Maximum|Minimum)" -v

test-fuzz-failing:
	@echo "Running only failing fuzz tests (bug demonstrations)..."
	forge test --match-contract FuzzTests --match-test "testFuzz_(PaymentLogicBug|EconomicInvariantViolation|BugExistsAtAllScales)_WILL_FAIL" -vv

test-unit:
	@echo "Running all unit tests (both passing and failing)..."
	forge test --match-contract UnitTests -vv

test-unit-verbose:
	@echo "Running unit tests with detailed output..."
	forge test --match-contract UnitTests -vvv

test-unit-passing:
	@echo "Running only passing unit tests..."
	forge test --match-contract UnitTests --match-test "test_(MoonToken|MyNFT|Marketplace_BuyNFT_BasicFlow|Marketplace_Cannot|Marketplace_Insufficient|Marketplace_ListNFT|Marketplace_Multiple|Marketplace_Only|Marketplace_Payment|Marketplace_Platform|Marketplace_State|Marketplace_Very|Marketplace_Minimum)" -v

test-unit-failing:
	@echo "Running only failing unit tests (bug demonstrations)..."
	forge test --match-contract UnitTests --match-test "WILL_FAIL" -vv

test-forked:
	@echo "Running all forked unit tests (both passing and failing)..."
	forge test --match-contract ForkedUnitTests -vv

test-forked-verbose:
	@echo "Running forked tests with detailed output..."
	forge test --match-contract ForkedUnitTests -vvv

test-forked-passing:
	@echo "Running only passing forked tests..."
	forge test --match-contract ForkedUnitTests --match-test "test_Forked" -v

test-forked-failing:
	@echo "Running only failing forked tests (bug demonstrations)..."
	forge test --match-contract ForkedUnitTests --match-test "WILL_FAIL" -vv

exe: install build deploy
	@echo "All commands executed successfully"
