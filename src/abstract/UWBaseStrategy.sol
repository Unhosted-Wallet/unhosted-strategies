// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IUWMetadata} from "../interfaces/IUWMetadata.sol";

import {JBIpfsDecoder} from "../libraries/JBIpfsDecoder.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

abstract contract UWBaseStrategy is ERC165, IUWMetadata {
    // @notice Tracks the singleton instance of this strategy.
    UWBaseStrategy private immutable SINGLETON;
    // @notice The (encoded) metadata hash.
    bytes32 private encodedIpfsMetadata;

    constructor() {
        SINGLETON = this;
    }

    function setMetadata(bytes32 _ipfsMetadata) external {
        require(address(this) == address(SINGLETON));
        // TODO: Add another check to see if the sender is allowed to set this.
        encodedIpfsMetadata = _ipfsMetadata;
    }

    /// @notice Exposes the IPFS hash that contains the metadata of this strategy.
    /// @return the IPFS hash where the metadata for this strategy is located.
    function metadata() external view returns (string memory) {
        // If this address is an account delegate calling the strategy, forward the call to the singleton.
        if (address(this) != address(SINGLETON)) return SINGLETON.metadata();
        // Decode the ipfs hash and append it.
        return JBIpfsDecoder.decode("ipfs://", encodedIpfsMetadata);
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IUWMetadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
