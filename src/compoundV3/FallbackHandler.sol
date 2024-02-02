// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/* solhint-disable no-empty-blocks */
import {IFlashLoanReceiver} from "src/aaveV2/IAaveV2Strategy.sol";
import {IComet} from "src/compoundV3/helpers/IComet.sol";
import {ISwapRouter} from "src/uniswapV3/helpers/ISwapRouter.sol";
import {IERC20, SafeERC20} from "src/BaseStrategy.sol";

/**
 * @title Default Fallback Handler - returns true for known token callbacks
 *   @dev Handles EIP-1271 compliant isValidSignature requests.
 *  @notice inspired by Richard Meissner's <richard@gnosis.pm> implementation
 */
contract CompV3FallbackHandler is IFlashLoanReceiver {
    using SafeERC20 for IERC20;

    struct CompCollateralSwapData {
        address tokenOut;
        address comet;
    }

    ISwapRouter public immutable router;

    error InvalidInitiator();
    error SwapFailed();

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
        }

        return true;
    }

    function _collateralSwap(
        address[] calldata assets,
        uint256[] calldata amounts,
        bytes calldata data
    ) private {
        (, CompCollateralSwapData memory decodedData) = abi.decode(
            data,
            (uint8, CompCollateralSwapData)
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

        IERC20(decodedData.tokenOut).approve(decodedData.comet, newBalance);
        IComet(decodedData.comet).supplyTo(
            msg.sender,
            decodedData.tokenOut,
            newBalance
        );

        IComet(decodedData.comet).withdrawFrom(
            msg.sender,
            msg.sender, // to
            assets[0],
            amounts[0]
        );
    }
}
