// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../src/Marketplace.sol";
import "../src/ERC721.sol";
import "../src/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title FuzzTests
 * @dev Fuzz testing suite for the NFT marketplace
 * 
 * This file contains:
 * - Property-based tests with random inputs
 * - Boundary condition testing with extreme values
 * - Statistical verification across multiple runs
 * - Edge case discovery through random exploration
 * - Input validation with bounded random values
 * 
 * Fuzz testing helps discover:
 * - Unexpected edge cases with random inputs
 * - Integer overflow/underflow vulnerabilities  
 * - Gas optimization opportunities
 * - Invariant violations under stress
 * - Input validation weaknesses
 */
contract FuzzTests is Test, IERC721Receiver {
    NFTMarket market;
    MyNFT myNFT;
    MoonToken moonToken;
    
    address seller = address(0x1);
    address buyer = address(0x2);
    address creator = address(0x3);
    
    uint256 constant MAX_SUPPLY = 10000 * 10**18;
    uint256 constant MIN_PRICE = 1 wei;
    uint256 constant MAX_PRICE = 1000 * 10**18;
    uint256 constant MAX_ROYALTY = 9; // 9% max as per contract
    
    function setUp() public {
        moonToken = new MoonToken();
        market = new NFTMarket(address(moonToken));
        myNFT = new MyNFT(address(market));
        
        // Fund test accounts
        moonToken.transfer(seller, 3000 * 10**18);
        moonToken.transfer(buyer, 3000 * 10**18);
        moonToken.transfer(creator, 3000 * 10**18);
    }
    
    // ========================================
    // PASSING FUZZ TESTS ✅
    // These should work correctly with random inputs
    // ========================================
    
    /// @dev ✅ PASSING: NFT minting should work with any valid royalty
    function testFuzz_MintNFTWithValidRoyalty(uint256 royalty) public {
        // Bound royalty to valid range (1-9% as per contract)
        royalty = bound(royalty, 1, MAX_ROYALTY);
        
        vm.prank(seller);
        uint256 tokenId = myNFT.mintNFT("https://example.com/nft", royalty);
        
        // Verify NFT was minted correctly
        assertEq(myNFT.ownerOf(tokenId), seller);
        
        // Verify royalty was set correctly
        (uint256 returnedRoyalty, address returnedCreator) = myNFT.royaltyInfo(tokenId);
        assertEq(returnedRoyalty, royalty);
        assertEq(returnedCreator, seller);
    }
    
    /// @dev ✅ PASSING: Listing should work with any valid price
    function testFuzz_ListNFTWithValidPrice(uint256 price) public {
        // Bound price to reasonable range
        price = bound(price, MIN_PRICE, MAX_PRICE);
        
        // Mint NFT first
        vm.prank(seller);
        uint256 tokenId = myNFT.mintNFT("https://example.com/nft", 5);
        
        // List NFT
        vm.startPrank(seller);
        myNFT.approve(address(market), tokenId);
        market.listNFTs(address(myNFT), tokenId, price);
        vm.stopPrank();
        
        // Verify listing
        (uint256 storedTokenId, uint256 storedPrice,,,, bool sold) = market.marketItems(1);
        assertEq(storedTokenId, tokenId);
        assertEq(storedPrice, price);
        assertFalse(sold);
        
        // Verify NFT is held by marketplace
        assertEq(myNFT.ownerOf(tokenId), address(market));
    }
    
    /// @dev ✅ PASSING: Platform fee should always be within bounds
    function testFuzz_PlatformFeeAlwaysValid() public {
        uint256 platformFee = market.platformFee();
        
        // Platform fee should be reasonable (less than 10%)
        assertTrue(platformFee <= 100, "Platform fee should not exceed 10%");
        assertTrue(platformFee >= 0, "Platform fee should not be negative");
    }
    
    /// @dev ✅ PASSING: Token balances should be conserved in marketplace operations
    function testFuzz_TokenConservationInListing(uint256 price) public {
        price = bound(price, MIN_PRICE, MAX_PRICE);
        
        uint256 totalSupplyBefore = moonToken.totalSupply();
        
        // Mint and list NFT
        vm.prank(seller);
        uint256 tokenId = myNFT.mintNFT("https://example.com/nft", 5);
        
        vm.startPrank(seller);
        myNFT.approve(address(market), tokenId);
        market.listNFTs(address(myNFT), tokenId, price);
        vm.stopPrank();
        
        uint256 totalSupplyAfter = moonToken.totalSupply();
        
        // Token supply should be unchanged by listing
        assertEq(totalSupplyBefore, totalSupplyAfter);
    }
    
    /// @dev ✅ PASSING: Multiple NFTs can be minted with different royalties
    function testFuzz_MultipleNFTsWithDifferentRoyalties(uint8 count, uint256 baseRoyalty) public {
        count = uint8(bound(count, 1, 10)); // Test with 1-10 NFTs
        baseRoyalty = bound(baseRoyalty, 1, MAX_ROYALTY);
        
        vm.startPrank(seller);
        for (uint256 i = 0; i < count; i++) {
            uint256 royalty = bound(baseRoyalty + i, 1, MAX_ROYALTY);
            uint256 tokenId = myNFT.mintNFT(string(abi.encodePacked("nft", i)), royalty);
            
            // Verify each NFT
            assertEq(myNFT.ownerOf(tokenId), seller);
            (uint256 returnedRoyalty,) = myNFT.royaltyInfo(tokenId);
            assertEq(returnedRoyalty, royalty);
        }
        vm.stopPrank();
    }
    
    // ========================================
    // FAILING FUZZ TESTS ❌
    // These expose bugs and edge cases
    // ========================================
    
    /// @dev ❌ FAILING: Payment logic bug exposed with any valid purchase
    function testFuzz_PaymentLogicBug_WILL_FAIL(uint256 price, uint256 royalty) public {
        // Bound inputs to valid ranges
        price = bound(price, MIN_PRICE, MAX_PRICE);
        royalty = bound(royalty, 1, MAX_ROYALTY);
        
        // Skip if buyer doesn't have enough tokens (focus on payment logic bug)
        uint256 maxRequired = price + (price * royalty) / 100 + (price * 25) / 1000;
        vm.assume(moonToken.balanceOf(buyer) >= maxRequired);
        
        // Setup: Mint and list NFT
        vm.prank(seller);
        uint256 tokenId = myNFT.mintNFT("https://example.com/nft", royalty);
        
        vm.startPrank(seller);
        myNFT.approve(address(market), tokenId);
        market.listNFTs(address(myNFT), tokenId, price);
        vm.stopPrank();
        
        // Record balances before purchase
        uint256 buyerBalanceBefore = moonToken.balanceOf(buyer);
        uint256 sellerBalanceBefore = moonToken.balanceOf(seller);
        
        // Execute purchase
        vm.startPrank(buyer);
        moonToken.approve(address(market), maxRequired);
        market.buyNFT(tokenId);
        vm.stopPrank();
        
        // Calculate actual amounts
        uint256 buyerPaid = buyerBalanceBefore - moonToken.balanceOf(buyer);
        uint256 sellerReceived = moonToken.balanceOf(seller) - sellerBalanceBefore;
        
        // Expected amounts
        uint256 expectedRoyaltyAmount = (price * royalty) / 100;
        uint256 expectedPlatformFee = (price * 25) / 1000;
        uint256 expectedBuyerPayment = price; // Should only pay listed price
        uint256 expectedSellerAmount = price - expectedRoyaltyAmount - expectedPlatformFee;
        
        // These assertions WILL FAIL due to payment logic bug
        assertEq(buyerPaid, expectedBuyerPayment, "FUZZ BUG: Buyer overpays regardless of price/royalty");
        assertEq(sellerReceived, expectedSellerAmount, "FUZZ BUG: Seller receives too much regardless of price/royalty");
    }
    
    /// @dev ❌ FAILING: Economic invariant violation across price ranges
    function testFuzz_EconomicInvariantViolation_WILL_FAIL(uint256 price) public {
        price = bound(price, MIN_PRICE, MAX_PRICE);
        
        // Skip if buyer doesn't have enough tokens
        uint256 maxRequired = price + (price * 5) / 100 + (price * 25) / 1000;
        vm.assume(moonToken.balanceOf(buyer) >= maxRequired);
        
        // Setup transaction
        vm.prank(seller);
        uint256 tokenId = myNFT.mintNFT("fuzz-nft", 5);
        
        vm.startPrank(seller);
        myNFT.approve(address(market), tokenId);
        market.listNFTs(address(myNFT), tokenId, price);
        vm.stopPrank();
        
        uint256 buyerBalanceBefore = moonToken.balanceOf(buyer);
        
        // Execute purchase
        vm.startPrank(buyer);
        moonToken.approve(address(market), maxRequired);
        market.buyNFT(tokenId);
        vm.stopPrank();
        
        uint256 actualBuyerLoss = buyerBalanceBefore - moonToken.balanceOf(buyer);
        
        // Economic invariant: Buyer should only lose the listed price
        assertEq(actualBuyerLoss, price, "FUZZ BUG: Economic invariant violated at any price level");
    }
    
    /// @dev ❌ FAILING: Royalty miscalculation across different rates
    function testFuzz_RoyaltyMiscalculation_WILL_FAIL(uint256 price, uint256 royalty) public {
        price = bound(price, MIN_PRICE, MAX_PRICE);
        royalty = bound(royalty, 1, MAX_ROYALTY);
        
        uint256 maxRequired = price + (price * royalty) / 100 + (price * 25) / 1000;
        vm.assume(moonToken.balanceOf(buyer) >= maxRequired);
        
        // Setup
        vm.prank(creator);
        uint256 tokenId = myNFT.mintNFT("creator-nft", royalty);
        
        // Transfer to seller for listing
        vm.prank(creator);
        myNFT.transferFrom(creator, seller, tokenId);
        
        vm.startPrank(seller);
        myNFT.approve(address(market), tokenId);
        market.listNFTs(address(myNFT), tokenId, price);
        vm.stopPrank();
        
        uint256 creatorBalanceBefore = moonToken.balanceOf(creator);
        
        // Execute purchase
        vm.startPrank(buyer);
        moonToken.approve(address(market), maxRequired);
        market.buyNFT(tokenId);
        vm.stopPrank();
        
        uint256 creatorReceived = moonToken.balanceOf(creator) - creatorBalanceBefore;
        uint256 expectedRoyalty = (price * royalty) / 100;
        
        // This will fail because royalty payment logic is wrong
        assertEq(creatorReceived, expectedRoyalty, "FUZZ BUG: Creator receives incorrect royalty amount");
    }
    
    /// @dev ❌ FAILING: Platform fee miscalculation across price ranges
    function testFuzz_PlatformFeeMiscalculation_WILL_FAIL(uint256 price) public {
        price = bound(price, MIN_PRICE, MAX_PRICE);
        
        uint256 maxRequired = price + (price * 5) / 100 + (price * 25) / 1000;
        vm.assume(moonToken.balanceOf(buyer) >= maxRequired);
        
        // Setup
        vm.prank(seller);
        uint256 tokenId = myNFT.mintNFT("platform-test", 5);
        
        vm.startPrank(seller);
        myNFT.approve(address(market), tokenId);
        market.listNFTs(address(myNFT), tokenId, price);
        vm.stopPrank();
        
        uint256 platformBalanceBefore = moonToken.balanceOf(address(this)); // Test contract is platform owner
        
        // Execute purchase
        vm.startPrank(buyer);
        moonToken.approve(address(market), maxRequired);
        market.buyNFT(tokenId);
        vm.stopPrank();
        
        uint256 platformReceived = moonToken.balanceOf(address(this)) - platformBalanceBefore;
        uint256 expectedPlatformFee = (price * 25) / 1000; // 2.5%
        
        // This will fail because platform fee calculation/distribution is wrong
        assertEq(platformReceived, expectedPlatformFee, "FUZZ BUG: Platform receives incorrect fee amount");
    }
    
    // ========================================
    // BOUNDARY AND EDGE CASE FUZZ TESTS
    // ========================================
    
    /// @dev ✅ PASSING: Test with minimum valid inputs
    function testFuzz_MinimumValidInputs() public {
        vm.prank(seller);
        uint256 tokenId = myNFT.mintNFT("min-test", 1); // 1% royalty (minimum)
        
        vm.startPrank(seller);
        myNFT.approve(address(market), tokenId);
        market.listNFTs(address(myNFT), tokenId, MIN_PRICE); // 1 wei (minimum)
        vm.stopPrank();
        
        // Verify listing worked with minimum inputs
        (uint256 storedTokenId, uint256 storedPrice,,,, bool sold) = market.marketItems(1);
        assertEq(storedTokenId, tokenId);
        assertEq(storedPrice, MIN_PRICE);
        assertFalse(sold);
    }
    
    /// @dev ✅ PASSING: Test with maximum valid inputs  
    function testFuzz_MaximumValidInputs() public {
        vm.prank(seller);
        uint256 tokenId = myNFT.mintNFT("max-test", MAX_ROYALTY); // 9% royalty (maximum)
        
        vm.startPrank(seller);
        myNFT.approve(address(market), tokenId);
        market.listNFTs(address(myNFT), tokenId, MAX_PRICE); // Maximum price
        vm.stopPrank();
        
        // Verify listing worked with maximum inputs
        (uint256 storedTokenId, uint256 storedPrice,,,, bool sold) = market.marketItems(1);
        assertEq(storedTokenId, tokenId);
        assertEq(storedPrice, MAX_PRICE);
        assertFalse(sold);
    }
    
    /// @dev ❌ FAILING: Test reveals bug exists at all price scales
    function testFuzz_BugExistsAtAllScales_WILL_FAIL(uint256 priceScale) public {
        // Test across different price scales (1 wei to 1000 tokens)
        priceScale = bound(priceScale, 0, 6); // 10^0 to 10^6 wei
        uint256 price = 10**priceScale;
        price = bound(price, MIN_PRICE, MAX_PRICE);
        
        uint256 maxRequired = price + (price * 5) / 100 + (price * 25) / 1000;
        vm.assume(moonToken.balanceOf(buyer) >= maxRequired);
        
        // Setup
        vm.prank(seller);
        uint256 tokenId = myNFT.mintNFT("scale-test", 5);
        
        vm.startPrank(seller);
        myNFT.approve(address(market), tokenId);
        market.listNFTs(address(myNFT), tokenId, price);
        vm.stopPrank();
        
        uint256 buyerBalanceBefore = moonToken.balanceOf(buyer);
        
        // Execute purchase
        vm.startPrank(buyer);
        moonToken.approve(address(market), maxRequired);
        market.buyNFT(tokenId);
        vm.stopPrank();
        
        uint256 actualPaid = buyerBalanceBefore - moonToken.balanceOf(buyer);
        
        // Bug exists regardless of price scale
        assertEq(actualPaid, price, "FUZZ BUG: Payment bug exists at all price scales");
    }
    
    // ========================================
    // HELPER FUNCTIONS
    // ========================================
    
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
