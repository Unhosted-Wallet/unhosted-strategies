// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IUWDebtHealthReport {

   /// @notice Reports the health of a position.
   /// @param position the position to check.
   /// @return current an amount that represents the current debt.
   /// @return max an amount at (or above) its no longer possible to take out additional debt against this position.
   /// @return liquidatable an amount at which the position is at risk of being liquidated.
   /// @dev these amounts define the thresholds, but their meaning is up to the strategy, it can be a health score, USD amounts, token amounts etc.
   function debtHealth(bytes32 position) external view returns (uint256 current, uint256 max, uint256 liquidatable);

}
