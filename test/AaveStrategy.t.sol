// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../src/UWAaveV2Strategy.sol";

import {Test, console} from "forge-std/Test.sol";

contract AaveStrategyTest is Test {
    uint256 MAINNET_FORK;
    UWAaveV2Strategy internal strategy;

    function setUp() public {
        // Configure forking mainnet
        MAINNET_FORK = vm.createFork("https://eth.drpc.org");
    }

    function testE2EMainnet(
        uint256 _depositAssetSeed,
        uint256 _depositAssetAmountSeed,
        uint256 _borrowAssetAmountSeed
    ) public {
        // Select mainnet fork.
        vm.selectFork(MAINNET_FORK);
        strategy = new UWAaveV2Strategy(
            IProtocolDataProvider(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d),
            WrappedETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
        );

        _testE2E(
            _depositAssetSeed,
            _depositAssetAmountSeed,
            _borrowAssetAmountSeed
        );
    }

    /// @notice Does a full E2E test of the comet, includes every action.
    function _testE2E(uint256, uint256, uint256) internal {
        // ILendingPoolV2 _pool = ILendingPoolV2(
        //     strategy.ADDRESSES().getLendingPool()
        // );

        vm.deal(address(strategy), 1 ether);

        // Deposit one of the available assets.
        strategy.deposit(
            bytes32(uint256(1)),
            UWConstants.NATIVE_ASSET,
            1 ether
        );

        strategy.debtHealth(bytes32(uint256(1)));

        strategy.borrow(
            bytes32(uint256(1)),
            // borrow USDT token.
            address(0xdAC17F958D2ee523a2206206994597C13D831ec7),
            100_000_000
        );

        strategy.debtHealth(bytes32(uint256(1)));

        strategy.borrow(
            bytes32(uint256(1)),
            // borrow wBTC token.
            address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599),
            4_500_000
        );

        strategy.debtHealth(bytes32(uint256(1)));
        strategy.assets(bytes32(uint256(1)));
    }
}
