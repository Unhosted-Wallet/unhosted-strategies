// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IUWErrors{
    error ASSET_AMOUNT_OUT_OF_BOUNDS(address asset, uint256 min, uint256 max, uint256 provided);
    error INVALID_POSITION(bytes32 position);
    error UNAVAILABLE_UNTIL(bytes32 position, uint256 timestamp);
    error UNAVAILABLE(bytes32 id);
    error UNSUPPORTED_ASSET(address asset);
}
