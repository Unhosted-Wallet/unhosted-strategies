// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUWDeposit} from "./interfaces/IUWDeposit.sol";
import {UWBaseStrategy} from "./abstract/UWBaseStrategy.sol";
import {UWConstants} from "./libraries/UWConstants.sol";
import {IUWErrors} from "./interfaces/IUWErrors.sol";

interface ILido is IERC20 {
    function submit(address _referral) external payable returns (uint256);
}

interface IwstETH is IERC20 {
    function wrap(uint256 _stETHAmount) external returns (uint256);
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
}

contract UWLidoStrategy is IUWDeposit, UWBaseStrategy {
    ILido internal immutable LIDO;
    IwstETH internal immutable wstETH;
    address internal immutable referral;

    constructor(ILido _lido, IwstETH _wstETH, address _referral) {
        LIDO = _lido;
        wstETH = _wstETH;
        referral = _referral;
    }

    /// @notice Deposit Ether into LIDO.
    /// @param position choose which asset to receive stETH or wstETH.
    /// @param asset UWConstants.NATIVE_ASSET is the only asset supported.
    /// @param amount the amount of ether to deposit.
    function deposit(bytes32 position, address asset, uint256 amount) external payable override {
        // Only native Ether is supported.
        if (asset != UWConstants.NATIVE_ASSET) revert IUWErrors.UNSUPPORTED_ASSET(asset);
        // Check that the position is one of the two available options.
        if (
            address(uint160(uint256(position))) != address(LIDO)
                && address(uint160(uint256(position))) != address(wstETH)
        ) {
            revert IUWErrors.INVALID_POSITION(position);
        }

        // Check that the amount to deposit is within the allowed bound of Lido and that the user has enough balance
        if (amount < 100 wei || amount > address(this).balance || amount > 1000 ether) {
            revert IUWErrors.ASSET_AMOUNT_OUT_OF_BOUNDS(
                asset, 100 wei, address(this).balance < 1000 ether ? address(this).balance : 1000 ether, amount
            );
        }

        // Perform the ETH -> stETH deposit
        uint256 _receivedAmount = LIDO.submit{value: amount}(referral);

        // If the position was for wstETH, then we perform the stETH -> wstETH
        if (address(uint160(uint256(position))) == address(wstETH)) {
            LIDO.approve(address(wstETH), _receivedAmount);
            wstETH.wrap(_receivedAmount);
        }
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IUWDeposit).interfaceId || UWBaseStrategy.supportsInterface(interfaceId);
    }
}
