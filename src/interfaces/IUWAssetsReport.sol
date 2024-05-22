// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Asset} from "../structs/Asset.sol";

/// @notice interface for position assets.
interface IUWAssetsReport {
    /// @notice Reports the asset value of a position.
    /// @param position the position to check.
    /// @return assets the assets that are in this position.
    function assets(
        bytes32 position
    ) external view returns (Asset[] memory assets);
}
