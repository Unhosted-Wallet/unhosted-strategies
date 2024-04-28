// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Asset} from "../structs/Asset.sol";

/// @notice interface for an deposit action.
interface IUWPositionReport {

   /// @notice Reports the asset value of a position.
   /// @dev The UI expects these assets to be belonging to the user, a leveraged position would not be a valid position, only the deposit.
   /// @param position the position to check.
   /// @return assets the assets that are in this position.
   function positionValue(bytes32 position) external view returns (Asset[] memory assets);
}
