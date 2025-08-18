//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/InterfaceRoyalty.sol";


contract NFTMarket is ReentrancyGuard, ERC721Holder{
    using Counters for Counters.Counter;
    Counters.Counter private _itemsIds;
    IERC20 public tokenAddress; 
    uint256 public platformFee = 25;

    address payable owner; 
    
    constructor(address _tokenAddress) {
        owner = payable(msg.sender);
        tokenAddress = IERC20(_tokenAddress);
    }

    struct NFTMarketItem{
        uint256 tokenId;
        uint256 price;
        address nftContract;
        address payable owner;
        address payable seller;
        bool sold;
    }

    mapping(uint256 => NFTMarketItem) public marketItems;

    event MarketItemCreated(
        uint256 indexed tokenId,
        uint256 price,
        uint256 royalty,
        address creator,
        address indexed nftContract,
        address owner,
        address seller, 
        bool sold  
    );


    function listNFTs(address nftContract, uint256 tokenId, uint256 price) external nonReentrant {
        require(price > 0, "Price must be atleast 1 Wei");
        
        _itemsIds.increment();
        uint256 itemId = _itemsIds.current();

        marketItems[itemId] = NFTMarketItem(
            tokenId,
            price,
            nftContract,
            payable(address(0)),
            payable(msg.sender),  
            false
        );

        NFTMarketItem memory nftMarketItem = marketItems[tokenId];

        (uint256 royaltyFee, address creator) = getRoyalty(nftMarketItem.nftContract, tokenId);

        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated( 
            tokenId,
            price,
            royaltyFee,
            creator,
            nftContract, 
            address(0),
            msg.sender,
            false
            );
    }

    function buyNFT(uint256 tokenId) external nonReentrant {
        NFTMarketItem memory nftMarketItem = marketItems[tokenId];
        (uint256 royaltyFee, address creator) = getRoyalty(nftMarketItem.nftContract, tokenId);

        require(nftMarketItem.sold == false, "NFT is not up for sale");
        require(tokenAddress.balanceOf(msg.sender) >= nftMarketItem.price, "Account balance is less than the price of the NFT");

        uint256 price = nftMarketItem.price;
        uint256 royaltyAmount = (price * royaltyFee) / 100;
        uint256 marketPlaceFee = (price * platformFee) / 1000;

        // Transfer the full sale price to the seller
        tokenAddress.transferFrom(msg.sender, nftMarketItem.seller, price);

        // Then, if applicable, transfer the royalty and marketplace fee
        if (royaltyAmount > 0) {
            tokenAddress.transferFrom(msg.sender, creator, royaltyAmount);
        }
        if (marketPlaceFee > 0) {
            tokenAddress.transferFrom(msg.sender, owner, marketPlaceFee);
        }

        marketItems[tokenId].owner = payable(msg.sender);
        marketItems[tokenId].sold = true;

        IERC721(marketItems[tokenId].nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
    }


    function getRoyalty(address nftContractAddress, uint256 _tokenId) internal view returns (uint256 _royalty, address _creator) {
            return InterfaceGetRoyalty(nftContractAddress).royaltyInfo(_tokenId);     
    }
}