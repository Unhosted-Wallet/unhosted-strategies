// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/* solhint-disable no-empty-blocks */
import {IFlashLoanReceiver, ILendingPoolV2} from "src/aaveV2/IAaveV2Strategy.sol";
import {ISwapRouter} from "src/uniswapV3/helpers/ISwapRouter.sol";
import {IERC20, SafeERC20} from "src/BaseStrategy.sol";

/**
 * @title Default Fallback Handler - returns true for known token callbacks
 *   @dev Handles EIP-1271 compliant isValidSignature requests.
 *  @notice inspired by Richard Meissner's <richard@gnosis.pm> implementation
 */
contract AaveV2FallbackHandler is IFlashLoanReceiver {
    using SafeERC20 for IERC20;

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

    ISwapRouter public immutable router;

    error InvalidInitiator();

    constructor(address router_) {
        router = ISwapRouter(router_);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata,
        address initiator,
        bytes calldata data
    ) external virtual returns (bool) {
        if (initiator != msg.sender) {
            revert InvalidInitiator();
        }
        uint8 mode = abi.decode(data, (uint8));

        if (mode == 1) {
            _collateralSwap(assets, amounts, data);
        } else if (mode == 2) {
            _debtSwap(assets, amounts, data);
        }

        return true;
    }

    function _collateralSwap(
        address[] calldata assets,
        uint256[] calldata amounts,
        bytes calldata data
    ) private {
        (, AaveCollateralSwapData memory decodedData) = abi.decode(
            data,
            (uint8, AaveCollateralSwapData)
        );
        IERC20(assets[0]).transferFrom(msg.sender, address(this), amounts[0]);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams(
                assets[0],
                decodedData.tokenOut,
                3000,
                address(this),
                block.timestamp,
                amounts[0],
                0,
                0
            );

        IERC20(assets[0]).forceApprove(address(router), amounts[0]);
        uint256 newBalance = router.exactInputSingle(params);

        IERC20(decodedData.tokenOut).approve(
            decodedData.lendingPool,
            newBalance
        );

        ILendingPoolV2(decodedData.lendingPool).deposit(
            decodedData.tokenOut,
            newBalance,
            msg.sender,
            0
        );

        IERC20(decodedData.aToken).transferFrom(
            msg.sender,
            address(this),
            amounts[0]
        );

        ILendingPoolV2(decodedData.lendingPool).withdraw(
            assets[0],
            amounts[0],
            msg.sender
        );
    }

    function _debtSwap(
        address[] calldata assets,
        uint256[] calldata amounts,
        bytes calldata data
    ) private {
        (, AaveDebtSwapData memory decodedData) = abi.decode(
            data,
            (uint8, AaveDebtSwapData)
        );
        IERC20(assets[0]).transferFrom(msg.sender, address(this), amounts[0]);
        IERC20(assets[0]).approve(decodedData.lendingPool, amounts[0]);

        ILendingPoolV2(decodedData.lendingPool).repay(
            assets[0],
            amounts[0],
            decodedData.repayRate,
            msg.sender
        );
        ILendingPoolV2(decodedData.lendingPool).borrow(
            decodedData.tokenOut,
            decodedData.amountToBorrow,
            decodedData.borrowRate,
            0,
            msg.sender
        );

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams(
                decodedData.tokenOut,
                assets[0],
                3000,
                msg.sender,
                block.timestamp,
                decodedData.amountToBorrow,
                0,
                0
            );

        IERC20(decodedData.tokenOut).forceApprove(
            address(router),
            decodedData.amountToBorrow
        );
        router.exactInputSingle(params);
    }
}
