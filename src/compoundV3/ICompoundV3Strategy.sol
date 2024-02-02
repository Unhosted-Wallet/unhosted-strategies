// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IComet} from "src/compoundV3/helpers/IComet.sol";
import {IWrappedNativeToken} from "src/interface/IWrappedNativeToken.sol";

interface ICompoundV3Strategy {

    struct CompCollateralSwapData {
        address tokenOut;
        address comet;
    }

    function supply(
        address comet,
        address asset,
        uint256 amount
    ) external payable;

    function supplyETH(address comet, uint256 amount) external payable;

    function withdraw(
        address comet,
        address asset,
        uint256 amount
    ) external payable returns (uint256 withdrawAmount);

    function withdrawETH(
        address comet,
        uint256 amount
    ) external payable returns (uint256 withdrawAmount);

    function borrow(
        address comet,
        uint256 amount
    ) external payable returns (uint256 borrowAmount);

    function borrowETH(
        address comet,
        uint256 amount
    ) external payable returns (uint256 borrowAmount);

    function repay(address comet, uint256 amount) external payable;

    function repayETH(address comet, uint256 amount) external payable;
}
