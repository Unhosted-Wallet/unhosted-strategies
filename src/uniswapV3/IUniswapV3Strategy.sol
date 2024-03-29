// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISwapRouter} from "src/uniswapV3/helpers/ISwapRouter.sol";
import {IWrappedNativeToken} from "src/interface/IWrappedNativeToken.sol";
import {BytesLib} from "src/uniswapV3/helpers/BytesLib.sol";

interface IUniswapV3Strategy {
    function exactInputSingleFromEther(
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    function exactInputSingleToEther(
        address tokenIn,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    function exactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    function exactInputFromEther(
        bytes memory path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    function exactInputToEther(
        bytes memory path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    function exactInput(
        bytes memory path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    function exactOutputSingleFromEther(
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) external payable returns (uint256 amountIn);

    function exactOutputSingleToEther(
        address tokenIn,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) external payable returns (uint256 amountIn);

    function exactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) external payable returns (uint256 amountIn);

    function exactOutputFromEther(
        bytes memory path,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint256 deadline
    ) external payable returns (uint256 amountIn);

    function exactOutputToEther(
        bytes memory path,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint256 deadline
    ) external payable returns (uint256 amountIn);

    function exactOutput(
        bytes memory path,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint256 deadline
    ) external payable returns (uint256 amountIn);
}
