// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @notice interface for an deposit action.
interface IUWDeposit {
    /// @notice emits once a user interacts with a (likely) new position. Signals to the UI to keep track of this position. 
    event TrackPosition(address indexed strategy, address indexed account, address asset);

    /// @notice Deposits into a strategy
    /// @param position specifies the position to deposit into, its up to the strategy implementation to decide what this refers to.
    /// @param asset the asset that is being deposited into this strategy.
    /// @param amount the amount of the asset to deposit.
    function deposit(bytes32 position, address asset, uint256 amount) payable external;
}
