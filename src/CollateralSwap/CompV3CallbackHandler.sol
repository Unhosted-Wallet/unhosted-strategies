// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/* solhint-disable no-empty-blocks */
import {IFlashLoanReceiver} from "@unhosted/handlers/aaveV2/CallbackHandler.sol";
import {ISwapRouter} from "@unhosted/handlers/uniswapV3/UniswapV3H.sol";
import {IERC20} from "@unhosted/handlers/BaseHandler.sol";
import {IComet} from "@unhosted/handlers/compoundV3/CompoundV3H.sol";

/**
 * @title Collateral swap flashloan callback handler
 * @dev This contract temporarily replaces the default handler of SA during the flashloan process
 */
contract FlashloanCallbackHandler is IFlashLoanReceiver {
    // prettier-ignore
    ISwapRouter public immutable router;

    struct ReceiveData {
        address tokenOut;
        address comet;
    }

    error InvalidInitiator();
    error SwapFailed();

    constructor(address router_) {
        router = ISwapRouter(router_);
    }

    /**
     * @dev Called by SA during the executeOperation of a flashloan
     * @dev Transfers the borrowed tokens from SA, swaps it for new collateral,
     * and supplies the new collateral, then withdraws the previous collateral to repay the loan
     */
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
        ReceiveData memory decodedData = abi.decode(data, (ReceiveData));
        {
            ISwapRouter.ExactInputSingleParams memory params;

            params.tokenIn = assets[0];
            params.tokenOut = decodedData.tokenOut;
            params.fee = 3000;
            params.recipient = address(this);
            params.amountIn = amounts[0];
            params.amountOutMinimum = 1;
            params.sqrtPriceLimitX96 = 0;
            params.deadline = block.timestamp;

            IERC20(assets[0]).transferFrom(msg.sender, address(this), amounts[0]);

            IERC20(assets[0]).approve(address(router), amounts[0]);
            try router.exactInputSingle(params) {}
            catch {
                revert SwapFailed();
            }
        }

        uint256 newBalance = IERC20(decodedData.tokenOut).balanceOf(address(this));
        IERC20(decodedData.tokenOut).approve(decodedData.comet, newBalance);
        IComet(decodedData.comet).supplyTo(msg.sender, decodedData.tokenOut, newBalance);

        IComet(decodedData.comet).withdrawFrom(
            msg.sender,
            msg.sender, // to
            assets[0],
            amounts[0]
        );

        return true;
    }
}
