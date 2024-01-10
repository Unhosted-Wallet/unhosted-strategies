// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeERC20} from "@unhosted/handlers/BaseHandler.sol";
import {AaveV2Handler, ILendingPoolAddressesProviderV2} from "@unhosted/handlers/aaveV2/AaveV2H.sol";
import {IVariableDebtToken} from "@unhosted/handlers/aaveV2/IVariableDebtToken.sol";
import {IQuoter} from "@unhosted/handlers/uniswapV3/IQuoter.sol";

/**
 * @title Aave v2 collateral swap handler
 * @dev Compatible with Unhosted strategy module
 */
contract AaveV2DebtSwap is AaveV2Handler {
    using SafeERC20 for IERC20;

    struct ReceiveData {
        address tokenOut;
        uint256 amountToBorrow;
        address lendingPool;
        uint256 repayRate;
        uint256 borrowRate;
    }

    address public immutable callbackHandler;
    address public immutable aaveDataProvider;
    IQuoter public immutable quoter;

    constructor(
        address wethAddress,
        address aaveV2Provider,
        address callbackHandler_,
        address aaveDataProvider_,
        address quoter_
    ) AaveV2Handler(wethAddress, aaveV2Provider, callbackHandler_) {
        callbackHandler = callbackHandler_;
        aaveDataProvider = aaveDataProvider_;
        quoter = IQuoter(quoter_);
    }

    /**
     * @dev Executes a collateral swap from the supplied token to another supported collateral token on Aave v2.
     * @param borrowedToken, Address of the currently borrowed token.
     * @param targetDebtToken, Address of the new token to borrow.
     * @param debtAmountToSwap, Amount of the current borrowed token to be swapped.
     * @param repayRate, rate of borrowed token to repay.
     * @param borrowRate, rate of new borrowed token.
     * @param debtMode, Flashloan mode for Aave (noDebt=0, stableDebt=1, variableDebt=2).
     */
    function debtSwap(
        address borrowedToken,
        address targetDebtToken,
        uint256 debtAmountToSwap,
        uint256 repayRate,
        uint256 borrowRate,
        uint256 debtMode
    ) public payable {
        uint256[] memory mode = new uint256[](1);
        uint256[] memory amount = new uint256[](1);
        address[] memory token = new address[](1);

        uint256 amountToBorrow = quoter.quoteExactOutputSingle(
            targetDebtToken,
            borrowedToken,
            3000,
            debtAmountToSwap,
            0
        );

        (, bytes memory receivedToken) = aaveDataProvider.staticcall(
            abi.encodeWithSignature(
                "getReserveTokensAddresses(address)",
                targetDebtToken
            )
        );

        (, address stableDebtToken, address variableDebtToken) = abi.decode(
            receivedToken,
            (address, address, address)
        );

        ReceiveData memory receiveData = ReceiveData(
            targetDebtToken,
            amountToBorrow,
            ILendingPoolAddressesProviderV2(provider).getLendingPool(),
            repayRate,
            borrowRate
        );
        mode[0] = debtMode;
        amount[0] = debtAmountToSwap;
        token[0] = borrowedToken;
        bytes memory data = abi.encode(receiveData);

        IERC20(borrowedToken).approve(callbackHandler, debtAmountToSwap);

        address newDebtToken = borrowRate == 1
            ? stableDebtToken
            : variableDebtToken;

        IVariableDebtToken(newDebtToken).approveDelegation(
            callbackHandler,
            amountToBorrow
        );
        flashLoan(token, amount, mode, data);
        IVariableDebtToken(newDebtToken).approveDelegation(callbackHandler, 0);
        IERC20(borrowedToken).approve(callbackHandler, 0);
    }

    function getContractName()
        public
        pure
        override(AaveV2Handler)
        returns (string memory)
    {
        return "CollateralSwapStrategy";
    }
}
