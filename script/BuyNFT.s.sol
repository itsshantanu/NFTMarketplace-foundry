// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../src/Marketplace.sol";
import "../src/ERC721.sol";
import "../src/ERC20.sol";

contract BuyNFT is Script {
    NFTMarket market = NFTMarket(0x71d2EBF08bF4FcB82dB5ddE46677263F4c534ef3);
    MyNFT myNFT = MyNFT(0x0BFC626B583e93A5F793Bc2cAa195BDBB2ED9F20);
    MoonToken moonToken = MoonToken(0x1c32f8818e38a50d37d1E98c72B9516a50985227);

    function run() external {
        address buyer = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266); // Replace with the buyer's address

        vm.startBroadcast(buyer);

        // Attempt to transfer more Ether than the contract has
        payable(address(0x123)).transfer(address(this).balance + 1 ether);

        // This line will not be reached if the above transfer fails
        uint256 totalAmount = 110 * 10 ** 18; // Adjust the total amount as needed
        moonToken.approve(address(market), totalAmount);

        // Buy the NFT
        market.buyNFT(2);

        vm.stopBroadcast();
    }
}