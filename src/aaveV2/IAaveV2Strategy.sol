// SPDX-License-Identifier: MIT
/// This is developed based on HAaveProtocolV2.sol by Furucombo
pragma solidity 0.8.20;

import {ILendingPoolV2} from "src/aaveV2/helpers/ILendingPoolV2.sol";
import {ILendingPoolAddressesProviderV2} from "src/aaveV2/helpers/ILendingPoolAddressesProviderV2.sol";
import {IWrappedNativeToken} from "src/interface/IWrappedNativeToken.sol";
import {DataTypes} from "src/aaveV2/helpers/DataTypes.sol";
import {IVariableDebtToken} from "src/aaveV2/helpers/IVariableDebtToken.sol";
import {IFlashLoanReceiver} from "src/aaveV2/helpers/IFlashLoanReceiver.sol";

interface IAaveV2Strategy {

    struct AaveCollateralSwapData {
        address tokenOut;
        address lendingPool;
        address aToken;
    }

    struct AaveDebtSwapData {
        address tokenOut;
        uint256 amountToBorrow;
        address lendingPool;
        uint256 repayRate;
        uint256 borrowRate;
    }

    function deposit(
        address asset,
        uint256 amount
    ) external payable returns (uint256 depositAmount);

    function depositETH(
        uint256 amount
    ) external payable returns (uint256 depositAmount);

    function withdraw(
        address asset,
        uint256 amount
    ) external payable returns (uint256 withdrawAmount);

    function withdrawETH(
        uint256 amount
    ) external payable returns (uint256 withdrawAmount);

    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external payable returns (uint256 remainDebt);

    function repayETH(
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external payable returns (uint256 remainDebt);

    function borrow(
        address asset,
        uint256 amount,
        uint256 rateMode
    ) external payable;

    function borrowETH(uint256 amount, uint256 rateMode) external payable;

    function flashLoan(
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory modes,
        bytes memory params
    ) external payable;

    function collateralSwap(
        address suppliedCollateralToken,
        address targetCollateralToken,
        uint256 collateralAmountToSwap,
        uint256 debtMode
    ) external payable;

    function debtSwap(
        address borrowedToken,
        address targetDebtToken,
        uint256 debtAmountToSwap,
        uint256 repayRate,
        uint256 borrowRate,
        uint256 debtMode
    ) external payable;
}
