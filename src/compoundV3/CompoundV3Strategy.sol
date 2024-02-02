// SPDX-License-Identifier: MIT
/// This is developed and simplified based on HCompoundV3.sol by Furucombo

pragma solidity 0.8.20;

import {BaseStrategy, IERC20, SafeERC20} from "src/BaseStrategy.sol";
import {AaveV2Strategy} from "src/aaveV2/AaveV2Strategy.sol";
import {ICompoundV3Strategy, IComet, IWrappedNativeToken} from "src/compoundV3/ICompoundV3Strategy.sol";

contract CompoundV3Strategy is
    BaseStrategy,
    AaveV2Strategy,
    ICompoundV3Strategy
{
    using SafeERC20 for IERC20;

    IWrappedNativeToken public immutable wrappedNativeTokenCompV3;
    address public immutable compFallbackHandler;

    constructor(
        address wrappedNativeToken_,
        address fallbackHandler_,
        address provider_,
        address aaveDataProvider_,
        address quoter_
    )
        AaveV2Strategy(
            wrappedNativeToken_,
            provider_,
            fallbackHandler_,
            aaveDataProvider_,
            quoter_
        )
    {
        wrappedNativeTokenCompV3 = IWrappedNativeToken(wrappedNativeToken_);
        compFallbackHandler = fallbackHandler_;
    }

    function supply(
        address comet,
        address asset,
        uint256 amount
    ) public payable {
        amount = _getBalance(asset, amount);
        if (amount == 0) {
            revert InvalidAmount();
        }
        _supply(
            comet,
            address(this), // Return to address(this)
            asset,
            amount
        );
    }

    function supplyETH(address comet, uint256 amount) public payable {
        if (amount == 0) {
            revert InvalidAmount();
        }
        amount = _getBalance(NATIVE_TOKEN_ADDRESS, amount);
        wrappedNativeTokenCompV3.deposit{value: amount}();

        _supply(
            comet,
            address(this), // Return to address(this)
            address(wrappedNativeTokenCompV3),
            amount
        );
    }

    function withdraw(
        address comet,
        address asset,
        uint256 amount
    ) public payable returns (uint256 withdrawAmount) {
        if (amount == 0) {
            revert InvalidAmount();
        }

        // No _getBalance: because we use comet.allow() to help users withdraw
        bool isBorrowed;
        (withdrawAmount, isBorrowed) = _withdraw(
            comet,
            address(this), // from
            asset,
            amount
        );

        // Borrow is not allowed
        if (isBorrowed) {
            revert NotAllowed();
        }
    }

    function withdrawETH(
        address comet,
        uint256 amount
    ) public payable returns (uint256 withdrawAmount) {
        if (amount == 0) {
            revert InvalidAmount();
        }

        // No _getBalance: because we use comet.allow() to help users withdraw
        bool isBorrowed;
        (withdrawAmount, isBorrowed) = _withdraw(
            comet,
            address(this), // from
            address(wrappedNativeTokenCompV3),
            amount
        );

        // Borrow is not allowed
        if (isBorrowed) {
            revert NotAllowed();
        }
        wrappedNativeTokenCompV3.withdraw(withdrawAmount);
    }

    function borrow(
        address comet,
        uint256 amount
    ) public payable returns (uint256 borrowAmount) {
        if (amount == 0) {
            revert InvalidAmount();
        }

        bool isBorrowed;
        address baseToken = IComet(comet).baseToken();
        (borrowAmount, isBorrowed) = _withdraw(
            comet,
            address(this), // from
            baseToken,
            amount
        );

        // Withdrawal is not allowed
        if (!isBorrowed) {
            revert NotAllowed();
        }
    }

    function borrowETH(
        address comet,
        uint256 amount
    ) public payable returns (uint256 borrowAmount) {
        if (IComet(comet).baseToken() != address(wrappedNativeTokenCompV3)) {
            revert InvalidComet();
        }
        if (amount == 0) {
            revert InvalidAmount();
        }

        bool isBorrowed;
        (borrowAmount, isBorrowed) = _withdraw(
            comet,
            address(this), // from
            address(wrappedNativeTokenCompV3),
            amount
        );

        // Withdrawal is not allowed
        if (!isBorrowed) {
            revert NotAllowed();
        }
        wrappedNativeTokenCompV3.withdraw(borrowAmount);
    }

    function repay(address comet, uint256 amount) public payable {
        if (amount == 0) {
            revert InvalidAmount();
        }

        address asset = IComet(comet).baseToken();
        amount = _getBalance(asset, amount);
        _supply(
            comet,
            address(this), // to
            asset,
            amount
        );
    }

    function repayETH(address comet, uint256 amount) public payable {
        if (IComet(comet).baseToken() != address(wrappedNativeTokenCompV3)) {
            revert InvalidComet();
        }
        if (amount == 0) {
            revert InvalidAmount();
        }

        amount = _getBalance(NATIVE_TOKEN_ADDRESS, amount);
        wrappedNativeTokenCompV3.deposit{value: amount}();
        _supply(
            comet,
            address(this), // to
            address(wrappedNativeTokenCompV3),
            amount
        );
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
        CompCollateralSwapData memory receiveData = CompCollateralSwapData(
            targetCollateralToken,
            comet
        );
        mode[0] = debtMode;
        amount[0] = collateralAmountToSwap;
        token[0] = suppliedCollateralToken;
        bytes memory data = abi.encode(uint8(1), receiveData);

        IComet(comet).allow(compFallbackHandler, true);
        IERC20(suppliedCollateralToken).approve(
            compFallbackHandler,
            collateralAmountToSwap
        );
        flashLoan(token, amount, mode, data);
        IComet(comet).allow(compFallbackHandler, false);
        IERC20(suppliedCollateralToken).approve(compFallbackHandler, 0);
    }

    function getStrategyName()
        public
        pure
        virtual
        override(AaveV2Strategy, BaseStrategy)
        returns (string memory)
    {
        return "CompoundV3";
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _supply(
        address comet,
        address dst,
        address asset,
        uint256 amount
    ) internal {
        IERC20(asset).forceApprove(comet, amount);
        /* solhint-disable no-empty-blocks */
        try IComet(comet).supplyTo(dst, asset, amount) {} catch Error(
            string memory reason
        ) {
            _revertMsg("supply", reason);
        } catch {
            _revertMsg("supply");
        }
        IERC20(asset).forceApprove(comet, 0);
    }

    function _withdraw(
        address comet,
        address from,
        address asset,
        uint256 amount
    ) internal returns (uint256 withdrawAmount, bool isBorrowed) {
        uint256 beforeBalance = IERC20(asset).balanceOf(address(this));
        uint256 borrowBalanceBefore = IComet(comet).borrowBalanceOf(from);

        try
            IComet(comet).withdrawFrom(
                from,
                address(this), // to
                asset,
                amount
            )
        {
            withdrawAmount =
                IERC20(asset).balanceOf(address(this)) -
                beforeBalance;
            isBorrowed =
                IComet(comet).borrowBalanceOf(from) > borrowBalanceBefore;
        } catch Error(string memory reason) {
            _revertMsg("withdraw", reason);
        } catch {
            _revertMsg("withdraw");
        }
    }
}
