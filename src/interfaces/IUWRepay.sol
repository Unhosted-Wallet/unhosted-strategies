// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @notice interface for a repay action.
interface IUWRepay {
   
    /// @notice repays using a strategy
    /// @param position specifies the position to repay, its up to the strategy implementation to decide what this refers to.
    /// @param asset the asset that is being repaid to this strategy.
    /// @param amount the amount of the asset to repay.
    function repay(bytes32 position, address asset, uint256 amount) external;
}
