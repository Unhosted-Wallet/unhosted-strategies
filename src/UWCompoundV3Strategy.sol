// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUWDeposit} from "./interfaces/IUWDeposit.sol";
import {IUWDepositBeneficiary} from "./interfaces/IUWDepositBeneficiary.sol";
import {IUWWithdraw} from "./interfaces/IUWWithdraw.sol";
import {IUWBorrow} from "./interfaces/IUWBorrow.sol";
import {IUWRepay} from "./interfaces/IUWRepay.sol";
import {IUWDebtReport} from "./interfaces/IUWDebtReport.sol";
import {IUWDebtHealthReport} from "./interfaces/IUWDebtHealthReport.sol";
import {IUWAssetsReport, Asset} from "./interfaces/IUWAssetsReport.sol";
import {UWBaseStrategy} from "./abstract/UWBaseStrategy.sol";
import {UWConstants} from "./libraries/UWConstants.sol";
import {IUWErrors} from "./interfaces/IUWErrors.sol";

interface IComet {
    struct AssetInfo {
        uint8 offset;
        address asset;
        address priceFeed;
        uint64 scale;
        uint64 borrowCollateralFactor;
        uint64 liquidateCollateralFactor;
        uint64 liquidationFactor;
        uint128 supplyCap;
    }

    struct UserBasic {
        int104 principal;
        uint64 baseTrackingIndex;
        uint64 baseTrackingAccrued;
        uint16 assetsIn;
        uint8 _reserved;
    }

    struct UserCollateral {
        uint128 balance;
        uint128 _reserved;
    }

    struct TotalsBasic {
        uint64 baseSupplyIndex;
        uint64 baseBorrowIndex;
        uint64 trackingSupplyIndex;
        uint64 trackingBorrowIndex;
        uint104 totalSupplyBase;
        uint104 totalBorrowBase;
        uint40 lastAccrualTime;
        uint8 pauseFlags;
    }

    function supply(address asset, uint256 amount) external;
    function supplyTo(address dst, address asset, uint256 amount) external;
    function withdrawTo(address to, address asset, uint256 amount) external;
    function getAssetInfo(uint8 i) external view returns (AssetInfo memory);
    function getAssetInfoByAddress(address asset) external view returns (AssetInfo memory);
    function getPrice(address feed) external view returns (uint256);
    function collateralBalanceOf(address account, address asset) external view returns (uint128);
    function baseToken() external view returns (address);
    function baseScale() external view returns (uint256);
    function baseTokenPriceFeed() external view returns (address);
    function baseBorrowMin() external view returns (uint256);
    function borrowBalanceOf(address account) external view returns (uint256);
    function totalsBasic() external view returns (TotalsBasic memory);
    function userBasic(address user) external view returns (UserBasic memory);
    function userCollateral(address user, address collateral) external view returns (UserCollateral memory);
    function numAssets() external view returns (uint8);
}

interface WrappedETH is IERC20 {
    function withdraw(uint256 wad) external;
    function deposit() external payable;
}

/// @notice Includes helper functions ripped from different contracts in Comet instead
/// of copying whole contracts. Also includes error definitions, events, and constants.
contract CometHelpers {
    uint64 internal constant FACTOR_SCALE = 1e18;
    uint64 internal constant BASE_INDEX_SCALE = 1e15;
    uint64 internal constant BASE_ACCRUAL_SCALE = 1e6;

    /**
     * @dev The positive present supply balance if positive or the negative borrow balance if negative
     */
    function presentValue(int104 principalValue_, uint64 _baseSupplyIndex, uint64 _baseBorrowIndex)
        internal
        pure
        returns (int256)
    {
        if (principalValue_ >= 0) {
            return signed256(presentValueSupply(_baseSupplyIndex, uint104(principalValue_)));
        } else {
            return -signed256(presentValueBorrow(_baseBorrowIndex, uint104(-principalValue_)));
        }
    }

    /// @dev Multiply a number by a factor
    /// https://github.com/compound-finance/comet/blob/main/contracts/Comet.sol#L681-L683
    function mulFactor(uint256 n, uint256 factor) internal pure returns (uint256) {
        return n * factor / FACTOR_SCALE;
    }

    /// @dev The principal amount projected forward by the supply index
    /// From https://github.com/compound-finance/comet/blob/main/contracts/CometCore.sol#L83-L85
    function presentValueSupply(uint64 baseSupplyIndex_, uint256 principalValue_) internal pure returns (uint256) {
        return principalValue_ * baseSupplyIndex_ / BASE_INDEX_SCALE;
    }

    /**
     * @dev The principal amount projected forward by the borrow index
     */
    function presentValueBorrow(uint64 baseBorrowIndex_, uint104 principalValue_) internal pure returns (uint256) {
        return uint256(principalValue_) * baseBorrowIndex_ / BASE_INDEX_SCALE;
    }

    /// @dev The present value projected backward by the supply index (rounded down)
    /// Note: This will overflow (revert) at 2^104/1e18=~20 trillion principal for assets with 18 decimals.
    /// From https://github.com/compound-finance/comet/blob/main/contracts/CometCore.sol#L109-L111
    function principalValueSupply(uint64 baseSupplyIndex_, uint256 presentValue_) internal pure returns (uint104) {
        return safe104((presentValue_ * BASE_INDEX_SCALE) / baseSupplyIndex_);
    }

    error InvalidUInt104();
    error InvalidInt256();
    error NegativeNumber();

    function safe104(uint256 n) internal pure returns (uint104) {
        if (n > type(uint104).max) revert InvalidUInt104();
        return uint104(n);
    }

    function signed256(uint256 n) internal pure returns (int256) {
        if (n > uint256(type(int256).max)) revert InvalidInt256();
        return int256(n);
    }

    function unsigned256(int256 n) internal pure returns (uint256) {
        if (n < 0) revert NegativeNumber();
        return uint256(n);
    }
}

contract UWCompoundV3Strategy is
    IUWDeposit,
    IUWDepositBeneficiary,
    IUWWithdraw,
    IUWBorrow,
    IUWRepay,
    IUWDebtHealthReport,
    UWBaseStrategy,
    CometHelpers
{
    WrappedETH internal immutable WETH;

    constructor(WrappedETH _weth) {
        WETH = _weth;
    }

    receive() external payable {}

    function deposit(bytes32 position, address asset, uint256 amount) external payable override {
        IComet _comet = IComet(address(uint160(uint256(position))));
        _depositTo(_comet, asset, amount, address(this));
    }

    function depositTo(bytes32 position, address asset, uint256 amount, address beneficiary) external payable {
        IComet _comet = IComet(address(uint160(uint256(position))));
        _depositTo(_comet, asset, amount, beneficiary);
    }

    function withdraw(bytes32 position, address asset, uint256 amount) external override {
        IComet _comet = IComet(address(uint160(uint256(position))));
        _withdrawTo(_comet, asset, amount, address(this));
    }

    function withdrawTo(bytes32 position, address asset, uint256 amount, address beneficiary) external override {
        IComet _comet = IComet(address(uint160(uint256(position))));
        _withdrawTo(_comet, asset, amount, beneficiary);
    }

    function borrow(bytes32 position, address asset, uint256 amount) external override {
        borrowTo(position, asset, amount, address(this));
    }

    function borrowTo(bytes32 position, address asset, uint256 amount, address beneficiary) public override {
        IComet _comet = IComet(address(uint160(uint256(position))));

        // We check that the comet supports the asset the user is trying to borrow.
        if (_comet.baseToken() != (asset == UWConstants.NATIVE_ASSET ? address(WETH) : asset)) {
            revert IUWErrors.UNSUPPORTED_ASSET(asset);
        }

        // Check that the borrow is above the min borrow.
        if (_comet.baseBorrowMin() > amount) {
            revert IUWErrors.ASSET_AMOUNT_OUT_OF_BOUNDS(asset, _comet.baseBorrowMin(), type(uint256).max, amount);
        }

        _withdrawTo(_comet, asset, amount, beneficiary);
    }

    function repay(bytes32 position, address asset, uint256 amount) external {
        IComet _comet = IComet(address(uint160(uint256(position))));

        // We check that this asset is the base asset, which means this is likely a repayment.
        if (_comet.baseToken() != (asset == UWConstants.NATIVE_ASSET ? address(WETH) : asset)) {
            revert IUWErrors.UNSUPPORTED_ASSET(asset);
        }

        // Check that the user is able to repay.
        if (_balanceOf(asset, address(this)) < amount) {
            uint256 _balance = _balanceOf(asset, address(this));
            uint256 _borrowAmount = _comet.borrowBalanceOf(address(this));
            revert IUWErrors.ASSET_AMOUNT_OUT_OF_BOUNDS(
                asset, 0, _borrowAmount < _balance ? _borrowAmount : _balance, amount
            );
        }

        // Compound handles repay the same as deposit, but we don't expose this behavior to UIs.
        _depositTo(_comet, asset, amount, address(this));
    }

    function debtHealth(bytes32 position) external view returns (uint256 current, uint256 max, uint256 liquidatable) {
        IComet _comet = IComet(address(uint160(uint256(position))));
        uint256 _borrowBalance = _comet.borrowBalanceOf(address(this));

        current = _borrowBalance;

        IComet.UserBasic memory _ub = _comet.userBasic(address(this));
        IComet.TotalsBasic memory _tb = _comet.totalsBasic();

        int256 liquidity = presentValue(_ub.principal, _tb.baseSupplyIndex, _tb.baseBorrowIndex)
            * signed256(_comet.getPrice(_comet.baseTokenPriceFeed())) / int256(uint256(_comet.baseScale()));

        int256 borrowLiquidity = liquidity;
        int256 zero_point = liquidity * -1;

        uint8 _na = _comet.numAssets();
        for (uint8 _i; _i < _na; _i++) {
            // TODO: add `isInAsset` optimization.
            IComet.AssetInfo memory _asset = _comet.getAssetInfo(_i);

            uint256 newAmount = _comet.collateralBalanceOf(address(this), _asset.asset)
                * _comet.getPrice(_asset.priceFeed) / _asset.scale;

            liquidity += signed256(mulFactor(newAmount, _asset.liquidateCollateralFactor));
            borrowLiquidity += signed256(mulFactor(newAmount, _asset.borrowCollateralFactor));
        }

        return (unsigned256(zero_point), unsigned256(zero_point + borrowLiquidity), unsigned256(zero_point + liquidity));
    }

    function _depositTo(IComet _comet, address _asset, uint256 _amount, address _beneficiary) internal {
        // Handle the native asset and normalize it.
        if (_asset == UWConstants.NATIVE_ASSET) {
            // Wrap ETH
            WETH.deposit{value: _amount}();
            // Continue as normal but set the token to be used to WETH.
            _asset = address(WETH);
        }

        // Approve the asset to be deposited.
        // TODO: Handle the max uint256 scenario.
        IERC20(_asset).approve(address(_comet), _amount);

        // Perform the deposit.
        _comet.supplyTo(_beneficiary, _asset, _amount);
    }

    function _withdrawTo(IComet _comet, address _asset, uint256 _amount, address _beneficiary) internal {
        // If the asset we are borrowing is an ERC20 we can exit early.
        if (_asset != UWConstants.NATIVE_ASSET) return _comet.withdrawTo(_beneficiary, _asset, _amount);

        // Borrow WETH.
        _comet.withdrawTo(address(this), address(WETH), _amount);

        // Unwrap thw WETH.
        WETH.withdraw(_amount);

        // Send it to the beneficiary if we are not the beneficiary.
        if (_beneficiary != address(this)) WETH.transfer(_beneficiary, _amount);
    }
}
