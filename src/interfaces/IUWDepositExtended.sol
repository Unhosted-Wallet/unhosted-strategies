// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @notice interface for a deposit action that requires additional data from the UI.
interface IUWDepositExtended {

    /// @notice Deposits into a strategy, requires the UI to pass in the data that is specific to this strategy.
    /// @param data special data field that holds additional required data for the strategy.
    function deposit(bytes calldata data) payable external;

}
