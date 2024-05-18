// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../src/UWCompoundV3Strategy.sol";

import {Test} from "forge-std/Test.sol";

contract CompoundStrategyTest is Test {
    IComet USDC_COMET =
        IComet(address(0xc3d688B66703497DAA19211EEdff47f25384cdc3));

    IComet WETH_COMET =
        IComet(address(0xA17581A9E3356d9A858b789D68B4d866e593aE94));

    WrappedETH WETH =
        WrappedETH(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

    IERC20 USDC = IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));

    UWCompoundV3Strategy strategy;

    function setUp() public {
        // Configure forking mainnet
        vm.createSelectFork("https://rpc.ankr.com/eth");

        vm.label(address(USDC_COMET), "USDC_COMET");
        vm.label(address(WETH_COMET), "WETH_COMET");

        vm.label(address(WETH), "WETH");
        vm.label(address(USDC), "USDC");

        strategy = new UWCompoundV3Strategy(WETH);
    }

    function testDepositBorrowWETH() public {
        uint256 amount = 2 ether;
        IERC20 asset = IERC20(
            address(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704)
        );

        deal(address(asset), address(strategy), amount);

        strategy.deposit(
            bytes32(uint256(uint160(address(WETH_COMET)))),
            address(asset),
            amount
        );
        strategy.borrow(
            bytes32(uint256(uint160(address(WETH_COMET)))),
            address(WETH),
            1 ether
        );

        // Assert that the new collateral is the amount deposited.
        strategy.debtHealth(bytes32(uint256(uint160(address(WETH_COMET)))));

        strategy.assets(bytes32(uint256(uint160(address(WETH_COMET)))));
        strategy.debt(bytes32(uint256(uint160(address(WETH_COMET)))));
    }

    //
    function testDepositNativeBorrowUSDC() public {
        uint256 deposit = 2 ether;
        uint256 borrow = 4_800_000_000;
        address wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

        vm.deal(address(strategy), deposit);
        strategy.deposit(
            bytes32(uint256(uint160(address(USDC_COMET)))),
            UWConstants.NATIVE_ASSET,
            deposit
        );

        // Assert that the new collateral is the amount deposited.
        assertEq(
            USDC_COMET.collateralBalanceOf(address(strategy), address(WETH)),
            deposit
        );
        deal(address(wbtc), address(strategy), 1 ether);
        strategy.deposit(
            bytes32(uint256(uint160(address(USDC_COMET)))),
            wbtc,
            100_000
        );

        strategy.borrow(
            bytes32(uint256(uint160(address(USDC_COMET)))),
            address(USDC),
            borrow
        );
        strategy.assets(bytes32(uint256(uint160(address(USDC_COMET)))));
    }
}
