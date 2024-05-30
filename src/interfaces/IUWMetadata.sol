// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @notice interface that has to be used by all modules and strategies and allows the UI to display information regarding it.
interface IUWMetadata {
    /// @notice Exposes the IPFS hash that contains the metadata of this strategy.
    /// @return ipfs the IPFS hash where the metadata for this strategy is located.
    function metadata() external view returns (string memory);
}
