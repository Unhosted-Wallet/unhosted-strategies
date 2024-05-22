// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Asset} from "../structs/Asset.sol";

/// @notice interface for an deposit action.
interface IUWDebtReport {
    /// @notice Reports the debt value of a position.
    /// @dev Make sure to balance this well with the `IUWPositionReport` and the assets in the users wallet to prevent the double counting of assets.
    /// @param position the position to check.
    /// @return assets the debt of the position.
    function debt(
        bytes32 position
    ) external view returns (Asset[] memory assets);
}
