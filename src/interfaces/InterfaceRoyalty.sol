//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface InterfaceGetRoyalty {
    function royaltyInfo(uint256 _tokenId) 
        external 
        view 
        returns (uint256 royalty, address creator);
}