// SPDX-License-Identifier: MIT
/// This is developed and simplified based on HUniswapV3.sol by Furucombo

pragma solidity 0.8.20;

import {BaseStrategy, SafeERC20, IERC20} from "src/BaseStrategy.sol";
import {IUniswapV3Strategy, ISwapRouter, IWrappedNativeToken, BytesLib} from "src/uniswapV3/IUniswapV3Strategy.sol";

contract UniswapV3Strategy is BaseStrategy, IUniswapV3Strategy {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // prettier-ignore
    ISwapRouter public immutable router;
    // prettier-ignore
    IWrappedNativeToken public immutable wrappedNativeTokenUniV3;

    uint256 private constant PATH_SIZE = 43; // address + address + uint24
    uint256 private constant ADDRESS_SIZE = 20;

    constructor(address wrappedNativeToken_, address router_) {
        wrappedNativeTokenUniV3 = IWrappedNativeToken(wrappedNativeToken_);
        router = ISwapRouter(router_);
    }

    function exactInputSingleFromEther(
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) public payable returns (uint256 amountOut) {
        // Build params for router call
        ISwapRouter.ExactInputSingleParams memory params;
        params.tokenIn = address(wrappedNativeTokenUniV3);
        params.tokenOut = tokenOut;
        params.fee = fee;
        params.amountIn = _getBalance(address(0), amountIn);
        params.amountOutMinimum = amountOutMinimum;
        params.sqrtPriceLimitX96 = sqrtPriceLimitX96;
        params.deadline = deadline;

        amountOut = _exactInputSingle(params.amountIn, params);
    }

    function exactInputSingleToEther(
        address tokenIn,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) public payable returns (uint256 amountOut) {
        // Build params for router call
        ISwapRouter.ExactInputSingleParams memory params;
        params.tokenIn = tokenIn;
        params.tokenOut = address(wrappedNativeTokenUniV3);
        params.fee = fee;
        params.amountIn = _getBalance(tokenIn, amountIn);
        params.amountOutMinimum = amountOutMinimum;
        params.sqrtPriceLimitX96 = sqrtPriceLimitX96;
        params.deadline = deadline;

        // Approve token
        IERC20(tokenIn).forceApprove(address(router), params.amountIn);
        amountOut = _exactInputSingle(0, params);
        IERC20(tokenIn).forceApprove(address(router), 0);
        wrappedNativeTokenUniV3.withdraw(amountOut);
    }

    function exactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) public payable returns (uint256 amountOut) {
        // Build params for router call
        ISwapRouter.ExactInputSingleParams memory params;
        params.tokenIn = tokenIn;
        params.tokenOut = tokenOut;
        params.fee = fee;
        params.amountIn = _getBalance(tokenIn, amountIn);
        params.amountOutMinimum = amountOutMinimum;
        params.sqrtPriceLimitX96 = sqrtPriceLimitX96;
        params.deadline = deadline;

        // Approve token
        IERC20(tokenIn).forceApprove(address(router), params.amountIn);
        amountOut = _exactInputSingle(0, params);
        IERC20(tokenIn).forceApprove(address(router), 0);
    }

    function exactInputFromEther(
        bytes memory path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline
    ) public payable returns (uint256 amountOut) {
        // Extract tokenIn and tokenOut
        address tokenIn = _getFirstToken(path);
        // Input token must be WETH
        if (tokenIn != address(wrappedNativeTokenUniV3)) {
            revert InvalidAddress();
        }
        // Build params for router call
        ISwapRouter.ExactInputParams memory params;
        params.path = path;
        params.amountIn = _getBalance(address(0), amountIn);
        params.amountOutMinimum = amountOutMinimum;
        params.deadline = deadline;

        amountOut = _exactInput(params.amountIn, params);
    }

    function exactInputToEther(
        bytes memory path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline
    ) public payable returns (uint256 amountOut) {
        // Extract tokenIn and tokenOut
        address tokenIn = _getFirstToken(path);
        address tokenOut = _getLastToken(path);
        // Output token must be WETH
        if (tokenOut != address(wrappedNativeTokenUniV3)) {
            revert InvalidAddress();
        }
        // Build params for router call
        ISwapRouter.ExactInputParams memory params;
        params.path = path;
        params.amountIn = _getBalance(tokenIn, amountIn);
        params.amountOutMinimum = amountOutMinimum;
        params.deadline = deadline;

        // Approve token
        IERC20(tokenIn).forceApprove(address(router), params.amountIn);
        amountOut = _exactInput(0, params);
        IERC20(tokenIn).forceApprove(address(router), 0);
        wrappedNativeTokenUniV3.withdraw(amountOut);
    }

    function exactInput(
        bytes memory path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline
    ) public payable returns (uint256 amountOut) {
        // Extract tokenIn
        address tokenIn = _getFirstToken(path);
        // Build params for router call
        ISwapRouter.ExactInputParams memory params;
        params.path = path;
        params.amountIn = _getBalance(tokenIn, amountIn);
        params.amountOutMinimum = amountOutMinimum;
        params.deadline = deadline;

        // Approve token
        IERC20(tokenIn).forceApprove(address(router), params.amountIn);
        amountOut = _exactInput(0, params);
        IERC20(tokenIn).forceApprove(address(router), 0);
    }

    function exactOutputSingleFromEther(
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) public payable returns (uint256 amountIn) {
        // Build params for router call
        ISwapRouter.ExactOutputSingleParams memory params;
        params.tokenIn = address(wrappedNativeTokenUniV3);
        params.tokenOut = tokenOut;
        params.fee = fee;
        params.amountOut = amountOut;
        params.deadline = deadline;
        // if amount == type(uint256).max return balance of Proxy
        params.amountInMaximum = _getBalance(address(0), amountInMaximum);
        params.sqrtPriceLimitX96 = sqrtPriceLimitX96;

        amountIn = _exactOutputSingle(params.amountInMaximum, params);
        router.refundETH();
    }

    function exactOutputSingleToEther(
        address tokenIn,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) public payable returns (uint256 amountIn) {
        // Build params for router call
        ISwapRouter.ExactOutputSingleParams memory params;
        params.tokenIn = tokenIn;
        params.tokenOut = address(wrappedNativeTokenUniV3);
        params.fee = fee;
        params.amountOut = amountOut;
        // if amount == type(uint256).max return balance of Proxy
        params.amountInMaximum = _getBalance(tokenIn, amountInMaximum);
        params.sqrtPriceLimitX96 = sqrtPriceLimitX96;
        params.deadline = deadline;

        // Approve token
        IERC20(params.tokenIn).forceApprove(
            address(router),
            params.amountInMaximum
        );
        amountIn = _exactOutputSingle(0, params);
        IERC20(params.tokenIn).forceApprove(address(router), 0);
        wrappedNativeTokenUniV3.withdraw(params.amountOut);
    }

    function exactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) public payable returns (uint256 amountIn) {
        // Build params for router call
        ISwapRouter.ExactOutputSingleParams memory params;
        params.tokenIn = tokenIn;
        params.tokenOut = tokenOut;
        params.fee = fee;
        params.amountOut = amountOut;
        // if amount == type(uint256).max return balance of Proxy
        params.amountInMaximum = _getBalance(tokenIn, amountInMaximum);
        params.sqrtPriceLimitX96 = sqrtPriceLimitX96;
        params.deadline = deadline;

        // Approve token
        IERC20(params.tokenIn).forceApprove(
            address(router),
            params.amountInMaximum
        );
        amountIn = _exactOutputSingle(0, params);
        IERC20(params.tokenIn).forceApprove(address(router), 0);
    }

    function exactOutputFromEther(
        bytes memory path,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint256 deadline
    ) public payable returns (uint256 amountIn) {
        // Extract tokenIn
        // Note that the first token is tokenOut in exactOutput functions, vice versa
        address tokenIn = _getLastToken(path);
        // Input token must be WETH
        if (tokenIn != address(wrappedNativeTokenUniV3)) {
            revert InvalidAddress();
        }
        // Build params for router call
        ISwapRouter.ExactOutputParams memory params;
        params.path = path;
        params.amountOut = amountOut;
        params.amountInMaximum = _getBalance(address(0), amountInMaximum);
        params.deadline = deadline;

        amountIn = _exactOutput(params.amountInMaximum, params);
        router.refundETH();
    }

    function exactOutputToEther(
        bytes memory path,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint256 deadline
    ) public payable returns (uint256 amountIn) {
        // Extract tokenIn and tokenOut
        // Note that the first token is tokenOut in exactOutput functions, vice versa
        address tokenIn = _getLastToken(path);
        address tokenOut = _getFirstToken(path);
        // Out token must be WETH
        if (tokenOut != address(wrappedNativeTokenUniV3)) {
            revert InvalidAddress();
        }
        // Build params for router call
        ISwapRouter.ExactOutputParams memory params;
        params.path = path;
        params.amountOut = amountOut;
        // if amount == type(uint256).max return balance of Proxy
        params.amountInMaximum = _getBalance(tokenIn, amountInMaximum);
        params.deadline = deadline;

        // Approve token
        IERC20(tokenIn).forceApprove(address(router), params.amountInMaximum);
        amountIn = _exactOutput(0, params);
        IERC20(tokenIn).forceApprove(address(router), 0);
        wrappedNativeTokenUniV3.withdraw(amountOut);
    }

    function exactOutput(
        bytes memory path,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint256 deadline
    ) public payable returns (uint256 amountIn) {
        // Extract tokenIn
        // Note that the first token is tokenOut in exactOutput functions, vice versa
        address tokenIn = _getLastToken(path);
        // Build params for router call
        ISwapRouter.ExactOutputParams memory params;
        params.path = path;
        params.amountOut = amountOut;
        // if amount == type(uint256).max return balance of Proxy
        params.amountInMaximum = _getBalance(tokenIn, amountInMaximum);
        params.deadline = deadline;

        // Approve token
        IERC20(tokenIn).forceApprove(address(router), params.amountInMaximum);
        amountIn = _exactOutput(0, params);
        IERC20(tokenIn).forceApprove(address(router), 0);
    }

    function getStrategyName()
        public
        pure
        virtual
        override
        returns (string memory)
    {
        return "UniswapV3";
    }

    function _exactInputSingle(
        uint256 value,
        ISwapRouter.ExactInputSingleParams memory params
    ) internal returns (uint256) {
        params.recipient = address(this);

        try router.exactInputSingle{value: value}(params) returns (
            uint256 amountOut
        ) {
            return amountOut;
        } catch Error(string memory reason) {
            _revertMsg("exactInputSingle", reason);
        } catch {
            _revertMsg("exactInputSingle");
        }
    }

    function _exactInput(
        uint256 value,
        ISwapRouter.ExactInputParams memory params
    ) internal returns (uint256) {
        params.recipient = address(this);

        try router.exactInput{value: value}(params) returns (
            uint256 amountOut
        ) {
            return amountOut;
        } catch Error(string memory reason) {
            _revertMsg("exactInput", reason);
        } catch {
            _revertMsg("exactInput");
        }
    }

    function _exactOutputSingle(
        uint256 value,
        ISwapRouter.ExactOutputSingleParams memory params
    ) internal returns (uint256) {
        params.recipient = address(this);

        try router.exactOutputSingle{value: value}(params) returns (
            uint256 amountIn
        ) {
            return amountIn;
        } catch Error(string memory reason) {
            _revertMsg("exactOutputSingle", reason);
        } catch {
            _revertMsg("exactOutputSingle");
        }
    }

    function _exactOutput(
        uint256 value,
        ISwapRouter.ExactOutputParams memory params
    ) internal returns (uint256) {
        params.recipient = address(this);

        try router.exactOutput{value: value}(params) returns (
            uint256 amountIn
        ) {
            return amountIn;
        } catch Error(string memory reason) {
            _revertMsg("exactOutput", reason);
        } catch {
            _revertMsg("exactOutput");
        }
    }

    function _getFirstToken(bytes memory path) internal pure returns (address) {
        return path.toAddress(0);
    }

    function _getLastToken(bytes memory path) internal pure returns (address) {
        if (path.length < PATH_SIZE) {
            revert InvalidPathSize();
        }
        return path.toAddress(path.length - ADDRESS_SIZE);
    }
}
