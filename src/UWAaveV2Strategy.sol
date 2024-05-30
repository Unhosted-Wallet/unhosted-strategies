// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {WrappedETH} from "./interfaces/external/common/WrappedETH.sol";
import {ILendingPoolV2} from "./interfaces/external/aave/ILendingPoolV2.sol";
import {ILendingPoolV2AddressesProvider} from "./interfaces/external/aave/ILendingPoolV2AddressesProvider.sol";
import {IProtocolDataProvider} from "./interfaces/external/aave/IProtocolDataProvider.sol";

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

contract UWAaveV2Strategy is
    IUWDeposit,
    IUWDepositBeneficiary,
    IUWWithdraw,
    IUWBorrow,
    IUWRepay,
    IUWAssetsReport,
    IUWDebtReport,
    IUWDebtHealthReport,
    UWBaseStrategy
{
    // ╭─ Immutable Properties ───────────────────────────────────────────╮
    IProtocolDataProvider public immutable DATA_PROVIDER;

    /// @notice provided the AaveV2 addresses to use
    ILendingPoolV2AddressesProvider public immutable ADDRESSES;

    /// @notice referral code that gets used for actions where we can pass one.
    uint16 public immutable REFERRAL;

    /// @notice the implementation of wrapped ether to use.
    WrappedETH public immutable WETH;
    // ╰─ Immutable Properties ───────────────────────────────────────────╯

    constructor(IProtocolDataProvider _dataProvider, WrappedETH _weth) {
        DATA_PROVIDER = _dataProvider;
        // We use the data provider to get the address provider, this way we minimize the chance of misconfiguration.
        ADDRESSES = _dataProvider.ADDRESSES_PROVIDER();

        WETH = _weth;

        // TODO: check if we can get a code.
        REFERRAL = uint16(0);
    }

    receive() external payable {}

    // ╭─ External & Public Functions ────────────────────────────────────╮
    /// @notice Deposit an asset into a compound comet.
    /// @param position the comet to use.
    /// @param asset the asset to deposit.
    /// @param amount the amount of the asset to deposit.
    function deposit(
        bytes32 position,
        address asset,
        uint256 amount
    ) external payable override onlySinglePosition(position) {
        _depositTo(asset, amount, address(this));
    }

    /// @notice Deposit an asset into a compound comet.
    /// @param position the comet to use.
    /// @param asset the asset to deposit.
    /// @param amount the amount of the asset to deposit.
    /// @param beneficiary the address to perform the deposit for.
    function depositTo(
        bytes32 position,
        address asset,
        uint256 amount,
        address beneficiary
    ) external payable onlySinglePosition(position) {
        _depositTo(asset, amount, address(beneficiary));
    }

    /// @notice Withdraw an asset from a compound comet.
    /// @param position the comet to use.
    /// @param asset the asset to withdraw.
    /// @param amount the amount of the asset to withdraw.
    function withdraw(
        bytes32 position,
        address asset,
        uint256 amount
    ) external override onlySinglePosition(position) {
        _withdrawTo(asset, amount, address(this));
    }

    /// @notice Withdraw an asset from a compound comet.
    /// @param position the comet to use.
    /// @param asset the asset to withdraw.
    /// @param amount the amount of the asset to withdraw.
    /// @param beneficiary the recipient of the withdrawn assets.
    function withdrawTo(
        bytes32 position,
        address asset,
        uint256 amount,
        address beneficiary
    ) external override onlySinglePosition(position) {
        _withdrawTo(asset, amount, beneficiary);
    }

    /// @notice Repay the base token for a compound comet.
    /// @param position the comet to use.
    /// @param asset the base asset to repay.
    /// @param amount the amount of the asset to repay.
    function repay(
        bytes32 position,
        address asset,
        uint256 amount
    ) external onlySinglePosition(position) {
        _repayTo(asset, amount, address(this));
    }

    /// @notice Borrow an asset from a compound comet.
    /// @param position the comet to use.
    /// @param asset the base asset to borrow.
    /// @param amount the amount of the asset to borrow.
    function borrow(
        bytes32 position,
        address asset,
        uint256 amount
    ) external override onlySinglePosition(position) {
        _borrowTo(asset, amount, address(this));
    }

    /// @notice Borrow an asset from a compound comet.
    /// @param position the comet to use.
    /// @param asset the base asset to borrow.
    /// @param amount the amount of the asset to borrow.
    /// @param beneficiary the recipient of the borrowed assets.
    function borrowTo(
        bytes32 position,
        address asset,
        uint256 amount,
        address beneficiary
    ) public override onlySinglePosition(position) {
        _borrowTo(asset, amount, beneficiary);
    }
    // ╰─ External & Public Functions ────────────────────────────────────╯

    // ╭─ View Functions ─────────────────────────────────────────────────╮
    /// @notice Reports on the amount of the users assets that are in this strategy.
    /// @param position the position to check.
    /// @return _assets of the position.
    function assets(
        bytes32 position
    )
        external
        view
        onlySinglePosition(position)
        returns (Asset[] memory _assets)
    {
        // TODO: this loads symbols as well, which we do not need.
        IProtocolDataProvider.TokenData[] memory _reserveAssets = DATA_PROVIDER
            .getAllATokens();

        // Reserve enough memory for all the assets.
        _assets = new Asset[](_reserveAssets.length);

        // Keep track of the number of assets actually deposited.
        uint256 _n;
        for (uint256 _i; _i < _reserveAssets.length; _i++) {
            uint256 _balance = IERC20(_reserveAssets[_i].tokenAddress)
                .balanceOf(address(this));

            if (_balance != 0) {
                _assets[_n++] = Asset({
                    asset: _reserveAssets[_i].tokenAddress,
                    amount: _balance
                });
            }
        }

        // Resize the assets to only contain filled asset structs.
        assembly {
            mstore(_assets, _n)
        }

        return _assets;
    }

    /// @notice Reports on the amount debt the user has to this strategy.
    /// @param position the position to check.
    /// @return _assets assets of the position.
    function debt(
        bytes32 position
    )
        external
        view
        onlySinglePosition(position)
        returns (Asset[] memory _assets)
    {
        // TODO: this loads symbols as well, which we do not need.
        IProtocolDataProvider.TokenData[] memory _reserveAssets = DATA_PROVIDER
            .getAllReservesTokens();

        // Reserve enough memory for all the assets.
        _assets = new Asset[](_reserveAssets.length);

        // Keep track of the number of assets actually deposited.
        uint256 _n;

        // TODO: Optimize gas usage
        for (uint256 _i; _i < _reserveAssets.length; _i++) {
            (
                ,
                uint256 _currentStableDebt,
                uint256 _currentVariableDebt,
                ,
                ,
                ,
                ,
                ,

            ) = DATA_PROVIDER.getUserReserveData(
                    _reserveAssets[_i].tokenAddress,
                    address(this)
                );

            // Check if the user has any debt for this asset.
            if (_currentVariableDebt != 0 || _currentStableDebt != 0) {
                (address _aTokenAddress, , ) = DATA_PROVIDER
                    .getReserveTokensAddresses(_reserveAssets[_i].tokenAddress);

                _assets[_n++] = Asset({
                    asset: _aTokenAddress,
                    amount: _currentVariableDebt + _currentStableDebt
                });
            }
        }

        // Resize the assets to only contain filled asset structs.
        assembly {
            mstore(_assets, _n)
        }

        return _assets;
    }

    /// @notice Reports the health of a position.
    /// @param position the position to check.
    /// @return current an amount that represents the current debt.
    /// @return max an amount at (or above) its no longer possible to take out additional debt against this position.
    /// @return liquidatable an amount at which the position is at risk of being liquidated.
    function debtHealth(
        bytes32 position
    )
        external
        view
        onlySinglePosition(position)
        returns (uint256, uint256, uint256)
    {
        // Get the pool address from the registry.
        ILendingPoolV2 _pool = ILendingPoolV2(ADDRESSES.getLendingPool());
        (
            uint256 _totalCollateralETH,
            uint256 _totalDebtETH,
            ,
            uint256 _currentLiquidationThreshold,
            uint256 _ltv,

        ) = _pool.getUserAccountData(address(this));

        return (
            // Calculate the current percentage of usage if there is any.
            _totalCollateralETH == 0
                ? 0
                : (_totalDebtETH * 1e4) / _totalCollateralETH,
            _ltv,
            _currentLiquidationThreshold
        );
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IUWDeposit).interfaceId ||
            interfaceId == type(IUWDepositBeneficiary).interfaceId ||
            interfaceId == type(IUWWithdraw).interfaceId ||
            interfaceId == type(IUWBorrow).interfaceId ||
            interfaceId == type(IUWRepay).interfaceId ||
            interfaceId == type(IUWAssetsReport).interfaceId ||
            interfaceId == type(IUWDebtReport).interfaceId ||
            interfaceId == type(IUWDebtHealthReport).interfaceId ||
            UWBaseStrategy.supportsInterface(interfaceId);
    }
    // ╰─ View Functions ─────────────────────────────────────────────────╯

    // ╭─ Internal Functions ─────────────────────────────────────────────╮
    function _depositTo(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal {
        ILendingPoolV2 _pool;
        (_pool, _asset) = _preSendFlow(_asset, _amount);

        try _pool.deposit(_asset, _amount, _beneficiary, REFERRAL) {} catch (
            bytes memory _revert
        ) {
            _handleRevert(_revert, _asset, _amount);
        }
    }

    function _repayTo(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal {
        ILendingPoolV2 _pool;
        (_pool, _asset) = _preSendFlow(_asset, _amount);

        (
            ,
            uint256 _currentStableDebt,
            uint256 _currentVariableDebt,
            ,
            ,
            ,
            ,
            ,

        ) = DATA_PROVIDER.getUserReserveData(_asset, address(this));

        if (_currentVariableDebt != 0) {
            uint256 _repay = _amount > _currentVariableDebt
                ? _currentVariableDebt
                : _amount;

            // Can't underflow due to above check.
            unchecked {
                _amount = _amount - _repay;
            }

            try
                _pool.repay(
                    _asset,
                    _repay,
                    uint256(ILendingPoolV2.InterestRateMode.VARIABLE),
                    _beneficiary
                )
            {} catch (bytes memory _revert) {
                _handleRevert(_revert, _asset, _amount);
            }
        }

        if (_currentStableDebt != 0 && _amount != 0) {
            try
                _pool.repay(
                    _asset,
                    _amount,
                    uint256(ILendingPoolV2.InterestRateMode.STABLE),
                    _beneficiary
                )
            {} catch (bytes memory _revert) {
                _handleRevert(_revert, _asset, _amount);
            }
        }
    }

    function _borrowTo(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal {
        // Get the pool address from the registry.
        ILendingPoolV2 _pool = ILendingPoolV2(ADDRESSES.getLendingPool());

        // If the asset we are withdrawing is an ERC20 we can exit early.
        if (_asset != UWConstants.NATIVE_ASSET) {
            try
                _pool.borrow(
                    _asset,
                    _amount,
                    uint256(ILendingPoolV2.InterestRateMode.VARIABLE),
                    REFERRAL,
                    _beneficiary
                )
            {} catch (bytes memory _revert) {
                _handleRevert(_revert, _asset, _amount);
            }

            return;
        }
        // Withdraw WETH to this address.
        try
            _pool.borrow(
                address(WETH),
                _amount,
                uint256(ILendingPoolV2.InterestRateMode.VARIABLE),
                REFERRAL,
                address(this)
            )
        {} catch (bytes memory _revert) {
            _handleRevert(_revert, _asset, _amount);
        }

        // Unwrap the WETH.
        WETH.withdraw(_amount);

        // Send it to the beneficiary if we are not the beneficiary.
        if (_beneficiary != address(this))
            SafeTransferLib.safeTransferETH(_beneficiary, _amount);
    }

    function _withdrawTo(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal {
        // Get the pool address from the registry.
        ILendingPoolV2 _pool = ILendingPoolV2(ADDRESSES.getLendingPool());

        // If the asset we are withdrawing is an ERC20 we can exit early.
        if (_asset != UWConstants.NATIVE_ASSET) {
            try _pool.withdraw(_asset, _amount, _beneficiary) {} catch (
                bytes memory _revert
            ) {
                _handleRevert(_revert, _asset, _amount);
            }
            return;
        }

        // Withdraw WETH to this address.
        try _pool.withdraw(address(WETH), _amount, address(this)) {} catch (
            bytes memory _revert
        ) {
            _handleRevert(_revert, _asset, _amount);
        }

        // Unwrap the WETH.
        WETH.withdraw(_amount);

        // Send it to the beneficiary if we are not the beneficiary.
        if (_beneficiary != address(this))
            SafeTransferLib.safeTransferETH(_beneficiary, _amount);
    }

    function _preSendFlow(
        address _asset,
        uint256 _amount
    ) internal returns (ILendingPoolV2, address) {
        // Handle the native asset and normalize it.
        if (_asset == UWConstants.NATIVE_ASSET) {
            // Wrap ETH
            WETH.deposit{value: _amount}();
            // Continue as normal but set the token to be used to WETH.
            _asset = address(WETH);
        }

        // Get the pool address from the registry.
        ILendingPoolV2 _pool = ILendingPoolV2(ADDRESSES.getLendingPool());

        // Approve the asset to be deposited.
        SafeTransferLib.safeApproveWithRetry(_asset, address(_pool), _amount);

        return (_pool, _asset);
    }

    function _handleRevert(
        bytes memory _revert,
        address _asset,
        uint256 _amount
    ) internal {
        bytes32 _error = keccak256(_revert);

        // We handle errors with regards to the asset being unsupported/unavailable.
        if (
            // 'Action requires an active reserve'
            _error ==
            keccak256(abi.encodeWithSignature("Error(string)", "2")) ||
            // 'Action cannot be performed because the reserve is frozen'
            _error ==
            keccak256(abi.encodeWithSignature("Error(string)", "3")) ||
            // 'Borrowing is not enabled'
            _error ==
            keccak256(abi.encodeWithSignature("Error(string)", "7")) ||
            // collateral is (mostly) the same currency that is being borrowed
            _error == keccak256(abi.encodeWithSignature("Error(string)", "13"))
        ) {
            revert IUWErrors.UNSUPPORTED_ASSET(_asset);
        }

        // We handle errors with regards to a user attempting a borrow when there is a lack of collateral.
        if (
            // 'User cannot withdraw more than the available balance'
            _error ==
            keccak256(abi.encodeWithSignature("Error(string)", "5")) ||
            // 'The collateral balance is 0'
            _error ==
            keccak256(abi.encodeWithSignature("Error(string)", "9")) ||
            // 'Health factor is lesser than the liquidation threshold'
            _error ==
            keccak256(abi.encodeWithSignature("Error(string)", "10")) ||
            // 'There is not enough collateral to cover a new borrow'
            _error ==
            keccak256(abi.encodeWithSignature("Error(string)", "11")) ||
            // User borrows on behalf, but allowance are too small
            _error == keccak256(abi.encodeWithSignature("Error(string)", "59"))
        ) {
            revert IUWErrors.ASSET_AMOUNT_OUT_OF_BOUNDS(_asset, 0, 0, _amount);
        }

        revert(string(_revert));
    }
    // ╰─ Internal Functions ─────────────────────────────────────────────╯
}
