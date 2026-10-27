// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployOurToken} from "script/DeployOurToken.s.sol";
import {OurToken} from "src/OurToken.sol";

interface MintableToken {
    function mint(address, uint256) external;
}

contract OurTokenTest is Test {
    OurToken public ourToken;
    DeployOurToken public deployer;

    address public bob = makeAddr("bob");
    address public alice = makeAddr("alice");
    address public charlie = makeAddr("charlie");

    uint256 public constant STARTING_BALANCE = 100 ether;

    function setUp() public {
        deployer = new DeployOurToken();
        ourToken = deployer.run();

        // Transfer starting balance to bob from whoever received initial supply
        vm.prank(msg.sender);
        ourToken.transfer(bob, STARTING_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                             INITIAL STATE
    //////////////////////////////////////////////////////////////*/

    function testInitialSupply() public view {
        assertEq(ourToken.totalSupply(), deployer.INITIAL_SUPPLY());
    }

    function testUsersCantMint() public {
        vm.expectRevert();
        MintableToken(address(ourToken)).mint(address(this), 1);
    }

    function testBobBalance() public view {
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
    }

    function testTokenMetadata() public view {
        assertEq(ourToken.name(), "OurToken");
        assertEq(ourToken.symbol(), "OT");
        assertEq(ourToken.decimals(), 18);
    }

    /*//////////////////////////////////////////////////////////////
                               TRANSFERS
    //////////////////////////////////////////////////////////////*/

    function testDirectTransferUpdatesBalances() public {
        uint256 transferAmount = 20 ether;

        vm.prank(bob);
        bool success = ourToken.transfer(alice, transferAmount);

        assertTrue(success);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
        assertEq(ourToken.balanceOf(alice), transferAmount);
    }

    function testTransferFailsWhenExceedingBalance() public {
        uint256 excessAmount = STARTING_BALANCE + 1;

        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(alice, excessAmount);
    }

    function testTransferToZeroAddressReverts() public {
        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(address(0), 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                              ALLOWANCES
    //////////////////////////////////////////////////////////////*/

    function testApproveSetsAllowance() public {
        uint256 allowanceAmount = 1000;

        vm.prank(bob);
        ourToken.approve(alice, allowanceAmount);

        assertEq(ourToken.allowance(bob, alice), allowanceAmount);
    }

    function testTransferFromWithinAllowance() public {
        uint256 initialAllowance = 1000;
        uint256 transferAmount = 400;

        // Bob approves Alice
        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        // Alice transfers from Bob to Charlie
        vm.prank(alice);
        ourToken.transferFrom(bob, charlie, transferAmount);

        // Check balances and remaining allowance
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
        assertEq(ourToken.balanceOf(charlie), transferAmount);
        assertEq(ourToken.allowance(bob, alice), initialAllowance - transferAmount);
    }

    function testTransferFromFailsWhenExceedingAllowance() public {
        uint256 initialAllowance = 500;
        uint256 transferAmount = 600;

        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, alice, transferAmount);
    }

    function testTransferFromFailsWhenOwnerHasInsufficientBalance() public {
        // Approve more than Bob's actual balance
        uint256 excessiveAllowance = STARTING_BALANCE + 50 ether;

        vm.prank(bob);
        ourToken.approve(alice, excessiveAllowance);

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, alice, excessiveAllowance);
    }
}
