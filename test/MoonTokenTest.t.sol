// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../src/ERC20.sol"; // Adjust the path to your MoonToken contract

contract MoonTokenTest is Test {
    MoonToken moonToken;
    address user1 = address(0x1); //test
    address user2 = address(0x2);

    function setUp() public {
        moonToken = new MoonToken();
    }

    function testInitialSupply() public {
        uint256 initialSupply = 10000 * 10 ** 18;
        assertEq(moonToken.totalSupply(), initialSupply, "Initial supply should match the minted amount");
        assertEq(moonToken.balanceOf(address(this)), initialSupply, "Deployer should have the initial supply");
    }

    function testTransfer() public {
        uint256 transferAmount = 100 * 10 ** 18;
        moonToken.transfer(user1, transferAmount);
        assertEq(moonToken.balanceOf(user1), transferAmount, "User1 should receive the correct amount");
    }

    function testBurn() public {
        uint256 burnAmount = 500 * 10 ** 18;
        moonToken.burn(burnAmount);
        assertEq(moonToken.totalSupply(), (10000 * 10 ** 18) - burnAmount, "Total supply should decrease by burn amount");
        assertEq(moonToken.balanceOf(address(this)), (10000 * 10 ** 18) - burnAmount, "Deployer's balance should decrease by burn amount");
    }
}
