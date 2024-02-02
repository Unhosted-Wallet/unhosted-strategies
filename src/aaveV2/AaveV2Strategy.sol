// SPDX-License-Identifier: MIT
/// This is developed based on HAaveProtocolV2.sol by Furucombo
pragma solidity 0.8.20;

import {BaseStrategy, IERC20, SafeERC20} from "src/BaseStrategy.sol";
import {
    IAaveV2Strategy,
    ILendingPoolV2,
    ILendingPoolAddressesProviderV2,
    IWrappedNativeToken,
    IVariableDebtToken,
    DataTypes
} from "src/aaveV2/IAaveV2Strategy.sol";
import "forge-std/console.sol";

contract AaveV2Strategy is BaseStrategy, IAaveV2Strategy {
    using SafeERC20 for IERC20;

    address public immutable provider;
    address public immutable quoter;
    address public immutable dataProvider;
    address public immutable aaveFallbackHandler;
    IWrappedNativeToken public immutable wrappedNativeTokenAaveV2;

    constructor(
        address wrappedNativeToken_,
        address provider_,
        address fallbackHandler_,
        address aaveDataProvider_,
        address quoter_
    ) {
        wrappedNativeTokenAaveV2 = IWrappedNativeToken(wrappedNativeToken_);
        provider = provider_;
        aaveFallbackHandler = fallbackHandler_;
        dataProvider = aaveDataProvider_;
        quoter = quoter_;
    }

    function deposit(address asset, uint256 amount) public payable returns (uint256 depositAmount) {
        amount = _getBalance(asset, amount);
        depositAmount = _deposit(asset, amount);
    }

    function depositETH(uint256 amount) public payable returns (uint256 depositAmount) {
        amount = _getBalance(NATIVE_TOKEN_ADDRESS, amount);
        wrappedNativeTokenAaveV2.deposit{value: amount}();
        depositAmount = _deposit(address(wrappedNativeTokenAaveV2), amount);
    }

    function withdraw(address asset, uint256 amount) public payable returns (uint256 withdrawAmount) {
        withdrawAmount = _withdraw(asset, amount);
    }

    function withdrawETH(uint256 amount) public payable returns (uint256 withdrawAmount) {
        withdrawAmount = _withdraw(address(wrappedNativeTokenAaveV2), amount);
        wrappedNativeTokenAaveV2.withdraw(withdrawAmount);
    }

    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf)
        public
        payable
        returns (uint256 remainDebt)
    {
        remainDebt = _repay(asset, amount, rateMode, onBehalfOf);
    }

    function repayETH(uint256 amount, uint256 rateMode, address onBehalfOf)
        public
        payable
        returns (uint256 remainDebt)
    {
        wrappedNativeTokenAaveV2.deposit{value: amount}();
        remainDebt = _repay(address(wrappedNativeTokenAaveV2), amount, rateMode, onBehalfOf);
    }

    function borrow(address asset, uint256 amount, uint256 rateMode) public payable {
        address onBehalfOf = address(this);
        _borrow(asset, amount, rateMode, onBehalfOf);
    }

    function borrowETH(uint256 amount, uint256 rateMode) public payable {
        address onBehalfOf = address(this);
        _borrow(address(wrappedNativeTokenAaveV2), amount, rateMode, onBehalfOf);
        wrappedNativeTokenAaveV2.withdraw(amount);
    }

    function collateralSwap(
        address suppliedCollateralToken,
        address targetCollateralToken,
        uint256 collateralAmountToSwap,
        uint256 debtMode
    ) public payable {
        uint256[] memory mode = new uint256[](1);
        uint256[] memory amount = new uint256[](1);
        address[] memory token = new address[](1);
        (, bytes memory receivedToken) = dataProvider.staticcall(
            abi.encodeWithSignature("getReserveTokensAddresses(address)", suppliedCollateralToken)
        );
        (address aToken,,) = abi.decode(receivedToken, (address, address, address));

        AaveCollateralSwapData memory receiveData = AaveCollateralSwapData(
            targetCollateralToken, ILendingPoolAddressesProviderV2(provider).getLendingPool(), aToken
        );
        mode[0] = debtMode;
        amount[0] = collateralAmountToSwap;
        token[0] = suppliedCollateralToken;
        bytes memory data = abi.encode(uint8(1), receiveData);

        IERC20(aToken).approve(aaveFallbackHandler, collateralAmountToSwap);
        IERC20(suppliedCollateralToken).approve(aaveFallbackHandler, collateralAmountToSwap);
        flashLoan(token, amount, mode, data);
        IERC20(aToken).approve(aaveFallbackHandler, 0);
        IERC20(suppliedCollateralToken).approve(aaveFallbackHandler, 0);
    }

    function debtSwap(
        address borrowedToken,
        address targetDebtToken,
        uint256 debtAmountToSwap,
        uint256 repayRate,
        uint256 borrowRate,
        uint256 debtMode
    ) public payable {
        uint256[] memory mode = new uint256[](1);
        uint256[] memory amount = new uint256[](1);
        address[] memory token = new address[](1);

        (, bytes memory receivedAmount) = quoter.call(
            abi.encodeWithSignature(
                "quoteExactOutputSingle(address,address,uint24,uint256,uint160)",
                targetDebtToken,
                borrowedToken,
                3000,
                debtAmountToSwap,
                0
            )
        );

        uint256 amountToBorrow = abi.decode(receivedAmount, (uint256));

        (, bytes memory receivedToken) =
            dataProvider.staticcall(abi.encodeWithSignature("getReserveTokensAddresses(address)", targetDebtToken));

        (, address stableDebtToken, address variableDebtToken) = abi.decode(receivedToken, (address, address, address));

        AaveDebtSwapData memory receiveData = AaveDebtSwapData(
            targetDebtToken,
            amountToBorrow,
            ILendingPoolAddressesProviderV2(provider).getLendingPool(),
            repayRate,
            borrowRate
        );
        mode[0] = debtMode;
        amount[0] = debtAmountToSwap;
        token[0] = borrowedToken;
        bytes memory data = abi.encode(uint8(2), receiveData);
        IERC20(borrowedToken).approve(aaveFallbackHandler, amount[0]);

        address newDebtToken = borrowRate == 1 ? stableDebtToken : variableDebtToken;

        IVariableDebtToken(newDebtToken).approveDelegation(aaveFallbackHandler, amountToBorrow);
        flashLoan(token, amount, mode, data);
        IVariableDebtToken(newDebtToken).approveDelegation(aaveFallbackHandler, 0);
        IERC20(token[0]).approve(aaveFallbackHandler, 0);
    }

    function flashLoan(address[] memory assets, uint256[] memory amounts, uint256[] memory modes, bytes memory params)
        public
        payable
    {
        {
            uint256 length = assets.length;
            if (length != amounts.length || length != modes.length) {
                revert NoArrayParity();
            }
        }
        address handler;
        address flashloanHandler = aaveFallbackHandler;
        address onBehalfOf = address(this);
        address pool = ILendingPoolAddressesProviderV2(provider).getLendingPool();

        for (uint256 i; i < assets.length;) {
            IERC20(assets[i]).forceApprove(pool, type(uint256).max);
            unchecked {
                ++i;
            }
        }

        assembly {
            handler := sload(FALLBACK_HANDLER_STORAGE_SLOT)

            sstore(FALLBACK_HANDLER_STORAGE_SLOT, flashloanHandler)
        }

        /* solhint-disable no-empty-blocks */
        try ILendingPoolV2(pool).flashLoan(address(this), assets, amounts, modes, onBehalfOf, params, 0) {}
        catch Error(string memory reason) {
            _revertMsg("flashLoan", reason);
        } catch {
            _revertMsg("flashLoan");
        }

        assembly {
            sstore(FALLBACK_HANDLER_STORAGE_SLOT, handler)
        }

        // approve lending pool zero
        for (uint256 i; i < assets.length;) {
            IERC20(assets[i]).forceApprove(pool, 0);
            unchecked {
                ++i;
            }
        }
    }

    function getStrategyName() public pure virtual override returns (string memory) {
        return "AaveV2";
    }

    function _deposit(address asset, uint256 amount) internal returns (uint256 depositAmount) {
        (address pool, address aToken) = _getLendingPoolAndAToken(asset);
        IERC20(asset).forceApprove(pool, amount);
        uint256 beforeATokenAmount = IERC20(aToken).balanceOf(address(this));

        /* solhint-disable no-empty-blocks */
        try ILendingPoolV2(pool).deposit(asset, amount, address(this), 0) {}
        catch Error(string memory reason) {
            _revertMsg("deposit", reason);
        } catch {
            _revertMsg("deposit");
        }

        unchecked {
            depositAmount = IERC20(aToken).balanceOf(address(this)) - beforeATokenAmount;
        }

        IERC20(asset).forceApprove(pool, 0);
    }

    function _withdraw(address asset, uint256 amount) internal returns (uint256 withdrawAmount) {
        (address pool, address aToken) = _getLendingPoolAndAToken(asset);
        amount = _getBalance(aToken, amount);

        try ILendingPoolV2(pool).withdraw(asset, amount, address(this)) returns (uint256 ret) {
            withdrawAmount = ret;
        } catch Error(string memory reason) {
            _revertMsg("withdraw", reason);
        } catch {
            _revertMsg("withdraw");
        }
    }

    function _repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf)
        internal
        returns (uint256 remainDebt)
    {
        address pool = ILendingPoolAddressesProviderV2(provider).getLendingPool();
        IERC20(asset).forceApprove(pool, amount);

        /* solhint-disable no-empty-blocks */
        try ILendingPoolV2(pool).repay(asset, amount, rateMode, onBehalfOf) {}
        catch Error(string memory reason) {
            _revertMsg("repay", reason);
        } catch {
            _revertMsg("repay");
        }
        IERC20(asset).forceApprove(pool, 0);

        DataTypes.ReserveData memory reserve = ILendingPoolV2(pool).getReserveData(asset);
        remainDebt = DataTypes.InterestRateMode(rateMode) == DataTypes.InterestRateMode.STABLE
            ? IERC20(reserve.stableDebtTokenAddress).balanceOf(onBehalfOf)
            : IERC20(reserve.variableDebtTokenAddress).balanceOf(onBehalfOf);
    }

    function _borrow(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) internal {
        address pool = ILendingPoolAddressesProviderV2(provider).getLendingPool();

        /* solhint-disable no-empty-blocks */
        try ILendingPoolV2(pool).borrow(asset, amount, rateMode, 0, onBehalfOf) {}
        catch Error(string memory reason) {
            _revertMsg("borrow", reason);
        } catch {
            _revertMsg("borrow");
        }
    }

    function _getLendingPoolAndAToken(address underlying) internal view returns (address pool, address aToken) {
        pool = ILendingPoolAddressesProviderV2(provider).getLendingPool();
        try ILendingPoolV2(pool).getReserveData(underlying) returns (DataTypes.ReserveData memory data) {
            aToken = data.aTokenAddress;
            if (aToken == address(0)) {
                revert InvalidAddress();
            }
        } catch Error(string memory reason) {
            _revertMsg("General", reason);
        } catch {
            _revertMsg("General");
        }
    }
}
