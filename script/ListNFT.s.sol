// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../src/Marketplace.sol"; 
import "../src/ERC721.sol"; 
import "../src/ERC20.sol";

contract ListNFT is Script {
    NFTMarket market = NFTMarket(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
    MyNFT myNFT = MyNFT(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);
    MoonToken moonToken = MoonToken(0x5FbDB2315678afecb367f032d93F642f64180aa3);

    function run() external {
        address owner = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266); // Fetch owner address from environment

        vm.startBroadcast(owner);

        // Mint an NFT to list
        string memory tokenURI = "https://example.com/nft";
        uint256 newItemId = myNFT.mintNFT(tokenURI, 5);
        myNFT.approve(address(market), newItemId);

        // List the NFT on the market
        uint256 price = 100 * 10 ** 18;
        market.listNFTs(address(myNFT), newItemId, price);

        vm.stopBroadcast();
    }
}

