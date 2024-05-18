// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IUWMetadata} from "../interfaces/IUWMetadata.sol";
import {UWConstants} from "../libraries/UWConstants.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract UWBaseStrategy is ERC165, IUWMetadata {
    // @notice Tracks the singleton instance of this strategy.
    UWBaseStrategy private immutable SINGLETON;

    constructor() {
        SINGLETON = this;
    }

    /// @notice Exposes the IPFS hash that contains the metadata of this strategy.
    /// @return ipfs the IPFS hash where the metadata for this strategy is located.
    function metadata() external view returns (bytes32 ipfs) {
        // If this address is an account delegate calling the strategy, forward the call to the singleton.
        if (address(this) != address(SINGLETON)) return SINGLETON.metadata();

        // TODO: Add IPFS
        return ipfs;
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IUWMetadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _balanceOf(
        address _asset,
        address _account
    ) internal view returns (uint256) {
        if (_asset == UWConstants.NATIVE_ASSET)
            return address(_account).balance;
        return IERC20(_asset).balanceOf(_account);
    }
}
