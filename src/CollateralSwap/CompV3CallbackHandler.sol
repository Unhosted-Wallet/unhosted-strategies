// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/* solhint-disable no-empty-blocks */
import {IFlashLoanReceiver} from "@unhosted/handlers/aaveV2/CallbackHandler.sol";
import {UniswapV3Handler} from "@unhosted/handlers/uniswapV3/UniswapV3H.sol";
import {IERC20} from "@unhosted/handlers/BaseHandler.sol";
import {IComet} from "@unhosted/handlers/compoundV3/CompoundV3H.sol";

/**
 * @title Collateral swap flashloan callback handler
 * @dev This contract temporarily replaces the default handler of SA during the flashloan process
 */
contract CompV3FlashloanCallbackHandler is
    UniswapV3Handler,
    IFlashLoanReceiver
{
    struct ReceiveData {
        address tokenOut;
        address comet;
    }

    error InvalidInitiator();
    error SwapFailed();

    constructor(
        address router_,
        address wethAddress
    ) UniswapV3Handler(wethAddress, router_) {}

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
        IERC20(assets[0]).transferFrom(msg.sender, address(this), amounts[0]);
        exactInputSingle(
            assets[0],
            decodedData.tokenOut,
            3000,
            amounts[0],
            0,
            0,
            block.timestamp
        );

        uint256 newBalance = IERC20(decodedData.tokenOut).balanceOf(
            address(this)
        );

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

        return true;
    }
}
