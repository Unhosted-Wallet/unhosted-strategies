// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/* solhint-disable no-empty-blocks */
import {IFlashLoanReceiver} from "@unhosted/handlers/aaveV2/CallbackHandler.sol";
import {UniswapV3Handler} from "@unhosted/handlers/uniswapV3/UniswapV3H.sol";
import {IERC20} from "@unhosted/handlers/BaseHandler.sol";
import {ILendingPoolV2} from "@unhosted/handlers/aaveV2/AaveV2H.sol";

/**
 * @title Collateral swap flashloan callback handler
 * @dev This contract temporarily replaces the default handler of SA during the flashloan process
 */
contract AaveV2FlashloanCallbackHandler is
    UniswapV3Handler,
    IFlashLoanReceiver
{
    struct ReceiveData {
        address tokenOut;
        uint256 amountToBorrow;
        address lendingPool;
        uint256 repayRate;
        uint256 borrowRate;
    }

    error InvalidInitiator();

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

        uint256 newAmount = exactInputSingle(
            decodedData.tokenOut,
            assets[0],
            3000,
            decodedData.amountToBorrow,
            0,
            0,
            block.timestamp
        );

        IERC20(assets[0]).transfer(msg.sender, newAmount);

        return true;
    }
}
