// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

library UWConstants {
    /// @notice If a strategy tracks everything using the users wallet and has no other concept of positions, then this represents the main position.
    bytes32 internal constant SINGLE_POSITION = bytes32(uint256(1));

    /// @notice The address that represents the native asset of the chain.
    address internal constant NATIVE_ASSET =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
}
