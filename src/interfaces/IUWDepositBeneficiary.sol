// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @notice interface for an deposit action with the ability to send it to a beneficiary.
interface IUWDepositBeneficiary {

    /// @notice Deposits into a strategy
    /// @param position specifies the position to deposit into, its up to the strategy implementation to decide what this refers to.
    /// @param asset the asset that is being deposited into this strategy.
    /// @param amount the amount of the asset to deposit.
    /// @param beneficiary recipient of the deposit.
    function depositTo(bytes32 position, address asset, uint256 amount, address beneficiary) payable external;
}
