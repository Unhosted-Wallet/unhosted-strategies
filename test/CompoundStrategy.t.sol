// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../src/UWCompoundV3Strategy.sol";

import {Test, console} from "forge-std/Test.sol";

contract CompoundStrategyTest is Test {
    uint256 MAINNET_FORK;
    uint256 POLYGON_FORK;
    uint256 ARBITRUM_FORK;
    uint256 OPTIMISM_FORK;
    uint256 BASE_FORK;

    UWCompoundV3Strategy strategy;

    function setUp() public {
        // Configure forking mainnet
        MAINNET_FORK = vm.createFork("https://eth.drpc.org");
        POLYGON_FORK = vm.createFork("https://polygon.rpc.blxrbdn.com");
        ARBITRUM_FORK = vm.createFork("https://arb-pokt.nodies.app");
        OPTIMISM_FORK = vm.createFork("https://op-pokt.nodies.app");
        BASE_FORK = vm.createFork("https://base-pokt.nodies.app");
    }

    function testE2EMainnet(
        uint256 _depositAssetSeed,
        uint256 _depositAssetAmountSeed,
        uint256 _borrowAssetAmountSeed
    ) public {
        // Select mainnet fork.
        vm.selectFork(MAINNET_FORK);
        strategy = new UWCompoundV3Strategy(
            WrappedETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
        );

        IComet _USDC_COMET = IComet(
            address(0xc3d688B66703497DAA19211EEdff47f25384cdc3)
        );
        IComet _WETH_COMET = IComet(
            address(0xA17581A9E3356d9A858b789D68B4d866e593aE94)
        );

        vm.label(address(_USDC_COMET), "USDC_COMET");
        vm.label(address(_WETH_COMET), "WETH_COMET");

        _testE2E(
            _USDC_COMET,
            _depositAssetSeed,
            _depositAssetAmountSeed,
            _borrowAssetAmountSeed
        );
        _testE2E(
            _WETH_COMET,
            _depositAssetSeed,
            _depositAssetAmountSeed,
            _borrowAssetAmountSeed
        );
    }

    function testE2EPolygon(
        uint256 _depositAssetSeed,
        uint256 _depositAssetAmountSeed,
        uint256 _borrowAssetAmountSeed
    ) public {
        // Select mainnet fork.
        vm.selectFork(POLYGON_FORK);
        strategy = new UWCompoundV3Strategy(
            // This is actually wrapped matic, but we expect the WETH implementation
            WrappedETH(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270)
        );

        IComet _USDC_COMET = IComet(
            address(0xF25212E676D1F7F89Cd72fFEe66158f541246445)
        );

        vm.label(address(_USDC_COMET), "USDC_COMET");

        _testE2E(
            _USDC_COMET,
            _depositAssetSeed,
            _depositAssetAmountSeed,
            _borrowAssetAmountSeed
        );
    }

    function testE2EArbitrum(
        uint256 _depositAssetSeed,
        uint256 _depositAssetAmountSeed,
        uint256 _borrowAssetAmountSeed
    ) public {
        // Select arbitrum fork.
        vm.selectFork(ARBITRUM_FORK);
        strategy = new UWCompoundV3Strategy(
            WrappedETH(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
        );

        IComet _USDC_COMET = IComet(
            address(0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf)
        );
        IComet _USDC_E_COMET = IComet(
            address(0xA5EDBDD9646f8dFF606d7448e414884C7d905dCA)
        );

        vm.label(address(_USDC_COMET), "USDC_COMET");
        vm.label(address(_USDC_E_COMET), "USDC.e_COMET");

        _testE2E(
            _USDC_COMET,
            _depositAssetSeed,
            _depositAssetAmountSeed,
            _borrowAssetAmountSeed
        );
        _testE2E(
            _USDC_E_COMET,
            _depositAssetSeed,
            _depositAssetAmountSeed,
            _borrowAssetAmountSeed
        );
    }

    function testE2EOptimism(
        uint256 _depositAssetSeed,
        uint256 _depositAssetAmountSeed,
        uint256 _borrowAssetAmountSeed
    ) public {
        // Select optimism fork.
        vm.selectFork(OPTIMISM_FORK);
        strategy = new UWCompoundV3Strategy(
            WrappedETH(0x4200000000000000000000000000000000000006)
        );

        IComet _USDC_COMET = IComet(
            address(0x2e44e174f7D53F0212823acC11C01A11d58c5bCB)
        );

        vm.label(address(_USDC_COMET), "USDC_COMET");

        _testE2E(
            _USDC_COMET,
            _depositAssetSeed,
            _depositAssetAmountSeed,
            _borrowAssetAmountSeed
        );
    }

    function testE2EBase(
        uint256 _depositAssetSeed,
        uint256 _depositAssetAmountSeed,
        uint256 _borrowAssetAmountSeed
    ) public {
        // Select base fork.
        vm.selectFork(BASE_FORK);
        strategy = new UWCompoundV3Strategy(
            WrappedETH(0x4200000000000000000000000000000000000006)
        );

        IComet _USDC_COMET = IComet(
            address(0xb125E6687d4313864e53df431d5425969c15Eb2F)
        );
        IComet _USDC_E_COMET = IComet(
            address(0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf)
        );
        IComet _WETH_COMET = IComet(
            address(0x46e6b214b524310239732D51387075E0e70970bf)
        );

        vm.label(address(_USDC_COMET), "USDC_COMET");
        vm.label(address(_USDC_E_COMET), "USDbC_COMET");
        vm.label(address(_WETH_COMET), "WETH_Comet");

        _testE2E(
            _USDC_COMET,
            _depositAssetSeed,
            _depositAssetAmountSeed,
            _borrowAssetAmountSeed
        );
        _testE2E(
            _USDC_E_COMET,
            _depositAssetSeed,
            _depositAssetAmountSeed,
            _borrowAssetAmountSeed
        );
        _testE2E(
            _WETH_COMET,
            _depositAssetSeed,
            _depositAssetAmountSeed,
            _borrowAssetAmountSeed
        );
    }

    /// @notice Does a full E2E test of the comet, includes every action.
    function _testE2E(
        IComet _comet,
        uint256 _depositAssetSeed,
        uint256 _depositAssetAmountSeed,
        uint256 _borrowAssetAmountSeed
    ) internal {
        address _baseToken = _comet.baseToken();

        // Get the asset we are going to deposit.
        // bound min is 1, since we don't want to deposit the base token.
        IComet.AssetInfo memory _depositAsset = _comet.getAssetInfo(
            uint8(bound(_depositAssetSeed, 0, _comet.numAssets() - 1))
        );

        uint256 _availableDeposit = _depositAsset.supplyCap -
            IERC20(_depositAsset.asset).balanceOf(address(_comet));

        uint256 _depositAmount = bound(
            _depositAssetAmountSeed,
            _depositAsset.scale,
            _availableDeposit
        );

        // Fund the strategy with the base asset
        deal(_depositAsset.asset, address(strategy), _depositAmount + 100);

        strategy.deposit(
            bytes32(uint256(uint160(address(_comet)))),
            _depositAsset.asset,
            _depositAmount
        );

        uint256 _balanceBefore = IERC20(_baseToken).balanceOf(
            address(strategy)
        );
        uint256 _borrowAmount;
        {
            // Calculate the worth of our colleteral.
            uint256 _worth = (_comet.getPrice(_depositAsset.priceFeed) *
                _comet.baseScale() *
                _depositAmount) /
                _comet.getPrice(_comet.baseTokenPriceFeed()) /
                _depositAsset.scale;

            // Calculate the maximum amount that we can borrow with the deposited colleteral.
            uint256 _maxBorrow = (_worth *
                _depositAsset.borrowCollateralFactor) / 1e18;

            // Check what the limiting factor is, is it our colleteral or is it the balance in the comet.
            uint256 _maxBorrowAvailable = IERC20(_baseToken).balanceOf(
                address(_comet)
            ) > _maxBorrow
                ? _maxBorrow
                : IERC20(_baseToken).balanceOf(address(_comet));

            // Give room for rounding errors.
            _maxBorrowAvailable = (_maxBorrowAvailable * 99) / 100;

            // Make sure that we can borrow the minimum amount.
            vm.assume(_comet.baseBorrowMin() < _maxBorrowAvailable);

            _borrowAmount = bound(
                _borrowAssetAmountSeed,
                _comet.baseBorrowMin(),
                _maxBorrowAvailable - 1
            );

            // Perform the borrow.
            strategy.borrow(
                bytes32(uint256(uint160(address(_comet)))),
                _baseToken,
                _borrowAmount
            );

            // Assert that we received the borrowed tokens.
            assertEq(
                IERC20(_baseToken).balanceOf(address(strategy)),
                _borrowAmount + _balanceBefore
            );
        }

        {
            uint256 _debt = strategy
            .debt(bytes32(uint256(uint160(address(_comet)))))[0].amount;

            // Repay the borrow with interest.
            deal(_baseToken, address(strategy), _debt);
            strategy.repay(
                bytes32(uint256(uint160(address(_comet)))),
                _baseToken,
                _debt
            );

            // Assert that we repaid the borrowed tokens.
            assertEq(IERC20(_baseToken).balanceOf(address(strategy)), 0);
        }

        strategy.withdraw(
            bytes32(uint256(uint160(address(_comet)))),
            _depositAsset.asset,
            strategy
            .assets(bytes32(uint256(uint160(address(_comet)))))[0].amount
        );
    }
}
