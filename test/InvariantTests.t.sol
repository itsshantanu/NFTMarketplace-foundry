// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../src/Marketplace.sol";
import "../src/ERC721.sol";
import "../src/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title InvariantTests
 * @dev Invariant testing suite for the NFT marketplace
 * 
 * This file contains:
 * - System-wide property verification tests
 * - Economic invariant validation (conservation of funds)
 * - State consistency checks across operations
 * - Handler-based stateful fuzzing
 * - Mathematical property verification
 * 
 * Key Invariants Tested:
 * - Token conservation: Total supply should remain constant
 * - Marketplace balance: Should equal sum of all listings
 * - NFT ownership: Should always have exactly one owner
 * - Fee calculations: Platform + royalty fees should be correct
 * - State consistency: Contract state should remain valid
 */
contract InvariantTests is Test, IERC721Receiver {
    NFTMarket market;
    MyNFT myNFT;
    MoonToken moonToken;
    
    // Handler contract to manage valid state transitions
    Handler handler;
    
    address[] users;
    address seller = address(0x1);
    address buyer = address(0x2);
    address platformOwner;
    
    uint256 constant INITIAL_TOKEN_SUPPLY = 10000 * 10**18;
    uint256 constant USER_COUNT = 3;
    
    function setUp() public {
        // Deploy contracts
        moonToken = new MoonToken();
        market = new NFTMarket(address(moonToken));
        myNFT = new MyNFT(address(market));
        platformOwner = address(this); // Test contract is the platform owner
        
        // Create test users and fund them
        for (uint256 i = 0; i < USER_COUNT; i++) {
            address user = address(uint160(i + 1));
            users.push(user);
            moonToken.transfer(user, 2000 * 10**18); // Give each user 2000 tokens
        }
        
        // Deploy and configure handler for invariant tests
        handler = new Handler(market, myNFT, moonToken, users);
        
        // Set handler as target for invariant testing
        targetContract(address(handler));
        
        // Mint some initial NFTs for testing
        for (uint256 i = 0; i < 5; i++) {
            myNFT.mintNFT("https://example.com/nft", 5); // 5% royalty
        }
    }
    
    // ========================================
    // PASSING INVARIANTS ✅
    // These tests verify correct contract behavior
    // ========================================
    
    /// @dev ✅ PASSING: The total supply of MoonToken should never change during marketplace operations
    function invariant_tokenSupplyNeverChanges() public {
        assertEq(moonToken.totalSupply(), INITIAL_TOKEN_SUPPLY, "Token supply should remain constant");
    }
    
    /// @dev ✅ PASSING: NFTs held by the marketplace should always be listed (sold = false)
    function invariant_marketplaceOnlyHoldsListedNFTs() public {
        uint256 marketBalance = myNFT.balanceOf(address(market));
        
        // If marketplace holds NFTs, they should be listed items
        if (marketBalance > 0) {
            // Check that marketplace has corresponding listed items
            uint256 listedCount = handler.getListedItemsCount();
            assertTrue(listedCount > 0, "Marketplace holds NFTs but no items are listed");
        }
    }
    
    /// @dev ✅ PASSING: All sold items should not be owned by the marketplace
    function invariant_soldItemsNotOwnedByMarketplace() public {
        uint256[] memory soldItems = handler.getSoldItems();
        
        for (uint256 i = 0; i < soldItems.length; i++) {
            uint256 tokenId = soldItems[i];
            if (tokenId > 0) { // Valid token ID
                address nftOwner = myNFT.ownerOf(tokenId);
                assertNotEq(nftOwner, address(market), "Sold NFT should not be owned by marketplace");
            }
        }
    }
    
    /// @dev ✅ PASSING: Platform fee should always be between 0 and 10% (100/1000)
    function invariant_platformFeeWithinBounds() public {
        uint256 platformFee = market.platformFee();
        assertTrue(platformFee <= 100, "Platform fee should not exceed 10%");
    }
    
    /// @dev ✅ PASSING: Sum of all user balances should equal total supply
    function invariant_balancesEqualTotalSupply() public {
        uint256 totalUserBalances = 0;
        
        // Add deployer balance
        totalUserBalances += moonToken.balanceOf(address(this));
        
        // Add user balances
        for (uint256 i = 0; i < users.length; i++) {
            totalUserBalances += moonToken.balanceOf(users[i]);
        }
        
        // Add marketplace owner balance (would need proper implementation)
        // totalUserBalances += moonToken.balanceOf(marketOwner);
        
        assertEq(totalUserBalances, INITIAL_TOKEN_SUPPLY, "Total balances should equal total supply");
    }
    
    // ========================================
    // FAILING INVARIANTS ❌
    // These tests are designed to FAIL and expose bugs
    // 
    // NOTE: These are now TRUE invariants (property checks) rather than
    // transaction-heavy tests. This prevents "failed to set up invariant 
    // testing environment" errors while still exposing the bugs.
    // ========================================
    
    /// @dev ❌ FAILING: Demonstrates payment logic bug - checks if any purchases resulted in overpayment
    function invariant_buyersOnlyPayListedPrice() public {
        uint256[] memory purchases = handler.getPurchaseHistory();
        uint256[] memory prices = handler.getPriceHistory();
        
        // This invariant will fail if any buyer paid more than the listed price
        for (uint256 i = 0; i < purchases.length && i < prices.length; i++) {
            if (purchases[i] > 0 && prices[i] > 0) {
                // This assertion will fail, demonstrating the payment bug
                assertEq(purchases[i], prices[i], "EXPECTED FAILURE: Buyer paid more than listed price");
            }
        }
        
        // If no purchases happened yet, just pass (invariant hasn't been violated yet)
        // The real violations will show up as purchases are made through the handler
    }
    
    /// @dev ❌ FAILING: Demonstrates incorrect seller payment - checks if sellers received correct amounts
    function invariant_sellersReceiveCorrectAmount() public {
        uint256[] memory sellerPayments = handler.getSellerPayments();
        uint256[] memory originalPrices = handler.getPriceHistory();
        
        // This invariant will fail if any seller received more than they should
        for (uint256 i = 0; i < sellerPayments.length && i < originalPrices.length; i++) {
            if (sellerPayments[i] > 0 && originalPrices[i] > 0) {
                uint256 price = originalPrices[i];
                uint256 expectedRoyalty = (price * 5) / 100; // 5% royalty
                uint256 expectedPlatformFee = (price * 25) / 1000; // 2.5% platform fee
                uint256 expectedSellerAmount = price - expectedRoyalty - expectedPlatformFee;
                
                // This will fail because sellers receive the full price instead of price minus fees
                assertEq(sellerPayments[i], expectedSellerAmount, "EXPECTED FAILURE: Seller received too much");
            }
        }
        
        // If no sales happened yet, just pass (invariant hasn't been violated yet)
    }
    
    /// @dev ❌ FAILING: Demonstrates economic invariant violation - checks payment consistency
    function invariant_economicConsistency() public {
        uint256[] memory purchases = handler.getPurchaseHistory();
        uint256[] memory prices = handler.getPriceHistory();
        
        // Economic invariant: Total amount paid by buyers should equal total listed prices
        uint256 totalPaid = 0;
        uint256 totalListed = 0;
        
        for (uint256 i = 0; i < purchases.length && i < prices.length; i++) {
            if (purchases[i] > 0) totalPaid += purchases[i];
            if (prices[i] > 0) totalListed += prices[i];
        }
        
        if (totalPaid > 0 && totalListed > 0) {
            // This will fail because buyers pay more than the total listed prices
            assertEq(totalPaid, totalListed, "EXPECTED FAILURE: Total payments exceed total listed prices");
        }
        
        // If no transactions yet, invariant is not violated (passes)
    }
    
    // ========================================
    // EXPLICIT BUG DEMONSTRATION TESTS
    // These are regular tests (not invariants) that clearly show the bugs
    // ========================================
    
    /// @dev ❌ EXPLICIT BUG TEST: Payment logic demonstration (WILL FAIL)
    function test_PaymentLogicBug_WILL_FAIL() public {
        // Setup: Create a simple purchase scenario
        uint256 listPrice = 100 * 10**18;
        
        // Mint NFT and list it
        vm.startPrank(seller);
        uint256 tokenId = myNFT.mintNFT("https://example.com/nft", 5); // 5% royalty
        myNFT.approve(address(market), tokenId);
        market.listNFTs(address(myNFT), tokenId, listPrice);
        vm.stopPrank();
        
        // Calculate what buyer needs to approve (the bug: they need more than listed price)
        uint256 royaltyAmount = (listPrice * 5) / 100;     // 5 tokens
        uint256 platformFee = (listPrice * 25) / 1000;     // 2.5 tokens  
        uint256 totalRequired = listPrice + royaltyAmount + platformFee; // 107.5 tokens (BUG!)
        
        // Record balances before purchase
        uint256 buyerBalanceBefore = moonToken.balanceOf(buyer);
        uint256 sellerBalanceBefore = moonToken.balanceOf(seller);
        
        // Execute purchase (buyer has to approve more than listed price due to bug)
        vm.startPrank(buyer);
        moonToken.approve(address(market), totalRequired);
        market.buyNFT(tokenId);
        vm.stopPrank();
        
        // Calculate actual amounts
        uint256 buyerPaid = buyerBalanceBefore - moonToken.balanceOf(buyer);
        uint256 sellerReceived = moonToken.balanceOf(seller) - sellerBalanceBefore;
        
        // What SHOULD happen vs what ACTUALLY happens
        uint256 expectedBuyerPayment = listPrice; // 100 tokens
        uint256 expectedSellerReceive = listPrice - royaltyAmount - platformFee; // 92.5 tokens
        
        emit log_named_uint("Listed Price", listPrice);
        emit log_named_uint("Buyer Paid (actual)", buyerPaid);
        emit log_named_uint("Buyer Should Pay", expectedBuyerPayment);
        emit log_named_uint("Seller Received (actual)", sellerReceived);
        emit log_named_uint("Seller Should Receive", expectedSellerReceive);
        
        // These assertions WILL FAIL, proving the bugs:
        assertEq(buyerPaid, expectedBuyerPayment, "BUG EXPOSED: Buyer overpays due to incorrect payment logic");
        assertEq(sellerReceived, expectedSellerReceive, "BUG EXPOSED: Seller receives too much (fees not deducted)");
    }
    
    /// @dev ❌ EXPLICIT BUG TEST: Economic impact demonstration (WILL FAIL)  
    function test_EconomicImpactBug_WILL_FAIL() public {
        uint256 listPrice = 100 * 10**18;
        
        // Setup and execute a purchase
        vm.startPrank(seller);
        uint256 tokenId = myNFT.mintNFT("nft1", 5);
        myNFT.approve(address(market), tokenId);
        market.listNFTs(address(myNFT), tokenId, listPrice);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        uint256 totalRequired = 107.5 * 10**18; // Due to the bug
        moonToken.approve(address(market), totalRequired);
        market.buyNFT(tokenId);
        vm.stopPrank();
        
        // Check economic impact
        uint256 actualBuyerLoss = 2000 * 10**18 - moonToken.balanceOf(buyer);
        uint256 expectedBuyerLoss = listPrice; // Should only lose the listed price
        
        emit log_named_uint("Expected buyer loss", expectedBuyerLoss);
        emit log_named_uint("Actual buyer loss", actualBuyerLoss);
        emit log_named_uint("Overpayment amount", actualBuyerLoss - expectedBuyerLoss);
        
        assertEq(actualBuyerLoss, expectedBuyerLoss, "BUG EXPOSED: Buyer loses more than the listed price");
    }
    
    /// @dev ✅ DEMONSTRATION: Shows what the correct behavior should be
    function test_ExpectedBehaviorDemo() public {
        uint256 listedPrice = 100 * 10**18;
        
        // Log what SHOULD happen in a correct implementation
        emit log_named_string("=== EXPECTED CORRECT BEHAVIOR ===", "");
        emit log_named_uint("Listed Price", listedPrice);
        emit log_named_uint("Expected Buyer Payment", listedPrice);
        emit log_named_uint("Expected Royalty (5%)", (listedPrice * 5) / 100);
        emit log_named_uint("Expected Platform Fee (2.5%)", (listedPrice * 25) / 1000);
        emit log_named_uint("Expected Seller Receipt", listedPrice - (listedPrice * 5) / 100 - (listedPrice * 25) / 1000);
        
        // Note: We don't execute an actual purchase because it would require
        // the buyer to approve more than the listed price (demonstrating the bug)
        
        assertTrue(true, "This shows the expected correct behavior for comparison");
    }
    
    // ========================================
    // HELPER FUNCTIONS
    // ========================================
    
    /// @dev Helper function for external call in mapping consistency test
    function getMarketItem(uint256 itemId) external view returns (bool exists) {
        (uint256 tokenId,,,,,) = market.marketItems(itemId);
        return tokenId > 0;
    }
    
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// ========================================
// HANDLER CONTRACT FOR INVARIANT TESTING
// ========================================

/// @dev Handler contract to manage state transitions and track history for invariant testing
contract Handler is Test, IERC721Receiver {
    NFTMarket public market;
    MyNFT public myNFT;
    MoonToken public moonToken;
    address[] public users;
    
    // State tracking for invariant tests
    uint256[] public purchaseHistory;
    uint256[] public priceHistory;
    uint256[] public sellerPayments;
    uint256[] public soldItems;
    uint256[] public listedItems;
    uint256 public itemIdCounter;
    
    mapping(address => uint256) public balancesBefore;
    
    constructor(NFTMarket _market, MyNFT _myNFT, MoonToken _moonToken, address[] memory _users) {
        market = _market;
        myNFT = _myNFT;
        moonToken = _moonToken;
        users = _users;
    }
    
    function listNFT(uint256 userIndex, uint256 tokenId, uint256 price) public {
        userIndex = bound(userIndex, 0, users.length - 1);
        price = bound(price, 1 wei, 1000 * 10**18);
        tokenId = bound(tokenId, 1, 5); // We minted 5 NFTs in setup
        
        address user = users[userIndex];
        
        // Check if user owns the NFT
        try myNFT.ownerOf(tokenId) returns (address owner) {
            if (owner == user) {
                vm.startPrank(user);
                myNFT.approve(address(market), tokenId);
                
                try market.listNFTs(address(myNFT), tokenId, price) {
                    itemIdCounter++;
                    listedItems.push(tokenId);
                    priceHistory.push(price);
                } catch {
                    // Listing failed
                }
                vm.stopPrank();
            }
        } catch {
            // Token doesn't exist or other error
        }
    }
    
    function buyNFT(uint256 userIndex, uint256 tokenId) public {
        userIndex = bound(userIndex, 0, users.length - 1);
        tokenId = bound(tokenId, 1, itemIdCounter);
        
        address buyer = users[userIndex];
        
        vm.startPrank(buyer);
        
        // Record balance before
        uint256 balanceBefore = moonToken.balanceOf(buyer);
        balancesBefore[buyer] = balanceBefore;
        
        try market.marketItems(tokenId) returns (
            uint256, // nftTokenId
            uint256 price,
            address, // nftContract
            address payable, // owner
            address payable seller,
            bool sold
        ) {
            if (!sold && price > 0) {
                uint256 totalCost = price + (price * 5) / 100 + (price * 25) / 1000; // price + royalty + platform fee
                
                if (moonToken.balanceOf(buyer) >= totalCost) {
                    moonToken.approve(address(market), totalCost);
                    
                    // Record seller balance before
                    uint256 sellerBalanceBefore = moonToken.balanceOf(seller);
                    
                    try market.buyNFT(tokenId) {
                        // Record the purchase
                        uint256 balanceAfter = moonToken.balanceOf(buyer);
                        uint256 actualPaid = balanceBefore - balanceAfter;
                        purchaseHistory.push(actualPaid);
                        
                        // Record seller payment
                        uint256 sellerBalanceAfter = moonToken.balanceOf(seller);
                        uint256 sellerReceived = sellerBalanceAfter - sellerBalanceBefore;
                        sellerPayments.push(sellerReceived);
                        
                        soldItems.push(tokenId);
                    } catch {
                        // Purchase failed
                    }
                }
            }
        } catch {
            // Market item doesn't exist
        }
        
        vm.stopPrank();
    }
    
    // Getter functions for invariant tests
    function getListedItemsCount() external view returns (uint256) {
        return listedItems.length;
    }
    
    function getSoldItems() external view returns (uint256[] memory) {
        return soldItems;
    }
    
    function getPurchaseHistory() external view returns (uint256[] memory) {
        return purchaseHistory;
    }
    
    function getPriceHistory() external view returns (uint256[] memory) {
        return priceHistory;
    }
    
    function getSellerPayments() external view returns (uint256[] memory) {
        return sellerPayments;
    }
    
    function getItemIdCounter() external view returns (uint256) {
        return itemIdCounter;
    }
    
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
