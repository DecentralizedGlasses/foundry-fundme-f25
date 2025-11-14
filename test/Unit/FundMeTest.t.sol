// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {FundMe} from "src/FundMe.sol";
import {DeployFundMe} from "script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    //we can declare state variables here
    FundMe fundMe;
    DeployFundMe deployFundMe;
    // Mock price feed address
    //address constant ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    //setUP() runs before each test function and this is must and should be external and be declared in an contract
    // Mainnet & Sepolia ETH/USD feeds (update if yours differs)
    address constant MAINNET_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant SEPOLIA_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether; // 0.1 ETH or 100000000000000000 wei
    uint256 constant STARTING_BALNCE = 10 ether;

    //uint256 constant GAS_PRICE = 1;

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALNCE);
    }

    //this is the testing function that tests the above setUP function
    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerISMsgSender() public {
        console.log("Owner address:", fundMe.i_owner());
        console.log("Msg sender address:", msg.sender);
        console.log("Test contract address:", address(this));
        assertEq(fundMe.getOwner(), msg.sender);
    }

    //what can we do to work with addresses outside our system
    // 1. unit test - Testing a specific part of our code
    // 2. integration - testing how our code works with oterh parts of our code
    // 3. Forked - testing code on a simulated real environment
    // 4. Staging - testing code in a real environment that is not production

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        if (block.chainid == 11155111) {
            uint256 version = fundMe.getVersion();
            assertEq(version, 4);
        } else if (block.chainid == 1) {
            uint256 version = fundMe.getVersion();
            assertEq(version, 6);
        } else {
            assertGt(version, 0);
        }
        // // console.log("Price Feed Version:", version);
        // // assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert();
        fundMe.fund(); // way below threshold
    }

    function testFundUpdatesFundedDataStructure() public funded {
        // vm.prank(USER); // The next tx will be sent by USER address
        // fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        assert(address(fundMe).balance > 0);
        _;
    }

    function testAddsFunderToArrayOfFunders() public funded {
        // vm.prank(USER);
        // fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    function testOnlyOwnerCanWithdraw() public funded {
        //vm.prank(USER);
        // fundMe.fund{value: SEND_VALUE}();

        vm.expectRevert(); //this line expects the next line to revert not the 'vm' line
        vm.prank(USER); // The next tx will be sent by USER address
        fundMe.withdraw();

        //console.log("Owner is able to withdraw", fundMe.i_owner());
    }

    function testWithdrawWithASingleFunder() public funded {
        //Arrange
        uint256 starttingOwnerBalance = fundMe.getOwner().balance;
        uint256 starttingFundMeBalance = address(fundMe).balance;

        //vm.txGasPrice(GAS_PRICE);
        //uint256 gasStart = gasleft();

        //Act

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        //uint256 gasEnd = gasleft();
        //uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        //console.log("gasUSED", gasUsed);

        //Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(starttingOwnerBalance + starttingFundMeBalance, endingOwnerBalance);
    }

    function testWithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10; //10 funders
        uint160 startingFunderIndex = 1; //index 0 is taken by 'USER' from the funded modifier
        for (
            uint160 i = startingFunderIndex; //1 to 10
            i < numberOfFunders + startingFunderIndex;

            //1 to 10
            i++
        ) {
            hoax(address(i), SEND_VALUE); //deal + prank = hoax
            fundMe.fund{value: SEND_VALUE}(); //funding the contract
        }

        uint256 startingFundMeBalance = address(fundMe).balance; //10 ETH
        uint256 startingOwnerBalance = fundMe.getOwner().balance; //owner balances

        vm.startPrank(fundMe.getOwner()); //pranking as the owner
        fundMe.withdraw(); //withdrawing the funds
        vm.stopPrank(); //stopping the prank

        assert(address(fundMe).balance == 0); //fundme balance is 0
        assert(
            startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance //owner balance after withdrawal
        );
        assert(
            (numberOfFunders + 1) * SEND_VALUE == fundMe.getOwner().balance - startingOwnerBalance //total funders' contribution
        );
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        uint160 numberOfFunders = 10; //10 funders
        uint160 startingFunderIndex = 1; //index 0 is taken by 'USER' from the funded modifier
        for (
            uint160 i = startingFunderIndex; //1 to 10
            i < numberOfFunders + startingFunderIndex;

            //1 to 10
            i++
        ) {
            hoax(address(i), SEND_VALUE); //deal + prank = hoax
            fundMe.fund{value: SEND_VALUE}(); //funding the contract
        }

        uint256 startingFundMeBalance = address(fundMe).balance; //10 ETH
        uint256 startingOwnerBalance = fundMe.getOwner().balance; //owner balances

        vm.startPrank(fundMe.getOwner()); //pranking as the owner
        fundMe.cheaperWithdraw(); //withdrawing the funds
        vm.stopPrank(); //stopping the prank

        assert(address(fundMe).balance == 0); //fundme balance is 0
        assert(
            startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance //owner balance after withdrawal
        );
        assert(
            (numberOfFunders + 1) * SEND_VALUE == fundMe.getOwner().balance - startingOwnerBalance //total funders' contribution
        );
    }

    function testPrintStorageData() public {
        for (uint256 i = 0; i < 3; i++) {
            bytes32 value = vm.load(address(fundMe), bytes32(i));
            console.log("Value at location", i, ":");
            console.logBytes32(value);
        }
        console.log("PriceFeed address:", address(fundMe.getPriceFeed()));
    }
}
