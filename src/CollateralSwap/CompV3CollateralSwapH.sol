// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IComet} from "@unhosted/handlers/compoundV3/CompoundV3H.sol";
import {BaseHandler, IERC20, SafeERC20} from "@unhosted/handlers/BaseHandler.sol";
import {AaveV2Handler, ILendingPoolAddressesProviderV2} from "@unhosted/handlers/aaveV2/AaveV2H.sol";

/**
 * @title Compound v3 collateral swap handler
 * @dev Compatible with Unhosted strategy module
 */
contract CompV3CollateralSwap is AaveV2Handler {
    using SafeERC20 for IERC20;

    address public immutable callbackHandler;

    constructor(address wethAddress, address aaveV2Provider, address callbackHandler_)
        AaveV2Handler(wethAddress, aaveV2Provider, callbackHandler_)
    {
        callbackHandler = callbackHandler_;
    }

    struct ReceiveData {
        address tokenOut;
        address comet;
    }

    /**
     * @dev Executes a collateral swap from the supplied token to another supported collateral token on Compound v3.
     * @param comet Address of the Compound contract used for collateral supply and withdrawal.
     * @param suppliedCollateralToken, Address of the currently supplied collateral token.
     * @param targetCollateralToken, Address of the new collateral token to be supplied.
     * @param collateralAmountToSwap, Amount of the current collateral token to be swapped.
     * @param debtMode, Flashloan mode for Aave (noDebt=0, stableDebt=1, variableDebt=2).
     */
    function collateralSwap(
        address comet,
        address suppliedCollateralToken,
        address targetCollateralToken,
        uint256 collateralAmountToSwap,
        uint256 debtMode
    ) public payable {
        uint256[] memory mode = new uint256[](1);
        uint256[] memory amount = new uint256[](1);
        address[] memory token = new address[](1);
        ReceiveData memory receiveData = ReceiveData(targetCollateralToken, comet);
        mode[0] = debtMode;
        amount[0] = collateralAmountToSwap;
        token[0] = suppliedCollateralToken;
        bytes memory data = abi.encode(receiveData);

        IComet(comet).allow(callbackHandler, true);
        IERC20(suppliedCollateralToken).approve(callbackHandler, collateralAmountToSwap);
        flashLoan(token, amount, mode, data);
        IComet(comet).allow(callbackHandler, false);
        IERC20(suppliedCollateralToken).approve(callbackHandler, 0);
    }

    function getContractName() public pure override(AaveV2Handler) returns (string memory) {
        return "CollateralSwapStrategy";
    }
}
