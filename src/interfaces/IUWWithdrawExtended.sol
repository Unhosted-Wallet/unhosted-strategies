// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @notice interface for a withdrawal action that requires additional data from the UI.
interface IUWWithdrawExtended {

    /// @notice Withdraws from a strategy, requires the UI to pass in the data that is specific to this strategy.
    /// @dev function is payable to not add any constraints, even if unlikely to be used. 
    /// @param data special data field that holds additional required data for the strategy.
    function withdraw(bytes calldata data) external payable;
}
