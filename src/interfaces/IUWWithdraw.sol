// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @notice interface for a withdrawal action.
interface IUWWithdraw {
   
    /// @notice withdraws from a strategy
    /// @param position specifies the position to withdraw from, its up to the strategy implementation to decide what this refers to.
    /// @param asset the asset that is being withdrawn from this strategy.
    /// @param amount the amount of the asset to withdraw.
    function withdraw(bytes32 position, address asset, uint256 amount) external;

    /// @notice withdraws from a strategy
    /// @param position specifies the position to withdraw from, its up to the strategy implementation to decide what this refers to.
    /// @param asset the asset that is being withdrawn from this strategy.
    /// @param amount the amount of the asset to withdraw.
    /// @param beneficiary the address that receives the asset that is being withdrawn.
    function withdrawTo(bytes32 position, address asset, uint256 amount, address beneficiary) external;
}
