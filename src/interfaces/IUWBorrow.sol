// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @notice interface for a borrow action.
interface IUWBorrow {
    /// @notice borrows using a strategy
    /// @param position specifies the position to borrow from, its up to the strategy implementation to decide what this refers to.
    /// @param asset the asset that is being borrowed from this strategy.
    /// @param amount the amount of the asset to borrow.
    function borrow(bytes32 position, address asset, uint256 amount) external;

    /// @notice borrows using a strategy
    /// @param position specifies the position to borrow from, its up to the strategy implementation to decide what this refers to.
    /// @param asset the asset that is being borrowed from this strategy.
    /// @param amount the amount of the asset to borrow.
    /// @param beneficiary recipient of the borrowed asset.
    function borrowTo(
        bytes32 position,
        address asset,
        uint256 amount,
        address beneficiary
    ) external;
}
