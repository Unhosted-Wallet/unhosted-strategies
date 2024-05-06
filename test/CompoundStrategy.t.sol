// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../src/UWCompoundV3Strategy.sol";

import {Test} from "forge-std/Test.sol";

contract CompoundStrategyTest is Test {
    IComet COMET = IComet(address(0xc3d688B66703497DAA19211EEdff47f25384cdc3));
    wETH WETH = wETH(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 USDC = IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
    UWCompoundV3Strategy strategy;

    function setUp() public {
        // Configure forking mainnet
        vm.createSelectFork("https://eth.llamarpc.com");

        vm.label(address(COMET), "COMET USDC");
        vm.label(address(WETH), "WETH");

        strategy = new UWCompoundV3Strategy(WETH);
    }

    function testDepositNative() public {
        uint256 amount = 2 ether;

        vm.deal(address(strategy), amount);
        strategy.deposit(bytes32(uint256(uint160(address(COMET)))), UWConstants.NATIVE_ASSET, amount);
        
        // Assert that the new colleteral is the amount deposited.
        assertEq(COMET.collateralBalanceOf(address(strategy), address(WETH)), amount);
    }

    function testDepositNativeBorrowUSDC() public {
        uint256 deposit = 2 ether;
        uint256 borrow = 100_000_000;

        vm.deal(address(strategy), deposit);
        strategy.deposit(bytes32(uint256(uint160(address(COMET)))), UWConstants.NATIVE_ASSET, deposit);
        
        // Assert that the new colleteral is the amount deposited.
        assertEq(COMET.collateralBalanceOf(address(strategy), address(WETH)), deposit);

        strategy.borrow(bytes32(uint256(uint160(address(COMET)))), address(USDC), borrow);
    }
}
