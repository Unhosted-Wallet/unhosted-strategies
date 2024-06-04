// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {IUWMetadata} from "./interfaces/IUWMetadata.sol";

struct Strategy {
    address strategy;
    string ipfs;
}

contract UWStrategyRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private strategies;

    event StrategyAdded(address strategy);
    event StrategyRemoved(address strategy);

    error INVALID_OFFSET(uint256 offset, uint256 max);
    error STRATEGY_ALREADY_IN_SET(address strategy);
    error STRATEGY_NOT_IN_SET(address strategy);

    modifier onlyUW() {
        // TODO: Add access control.
        _;
    }

    /// @notice Add a strategy to the set.
    function add(address _strategy) external onlyUW {
        // Add the strategy and make sure it wasn't already in the set.
        if (!strategies.add(_strategy))
            revert STRATEGY_ALREADY_IN_SET(_strategy);

        // Safety check to prevent an incorrect address from being added.
        ERC165Checker.supportsInterface(
            _strategy,
            type(IUWMetadata).interfaceId
        );

        emit StrategyAdded(_strategy);
    }

    /// @notice remove a strategy from the set.
    function remove(address _strategy) external onlyUW {
        // Remove the strategy and make sure it was in the set.
        if (!strategies.remove(_strategy))
            revert STRATEGY_NOT_IN_SET(_strategy);

        emit StrategyRemoved(_strategy);
    }

    function count() external view returns (uint256) {
        return strategies.length();
    }

    function get(
        uint256 offset,
        uint256 limit
    ) external view returns (Strategy[] memory _strategies) {
        uint256 _totalItems = strategies.length();
        uint256 _max = offset + limit;

        // Check that the request is valid.
        if (offset > _max) revert INVALID_OFFSET(offset, _totalItems);

        // If we exceed the total number of strategies then go up to the final item.
        if (_totalItems < _max) _max = _totalItems;
        _strategies = new Strategy[](_max - offset);

        uint256 _i;
        for (; offset < _max; offset++) {
            address _strategy = strategies.at(offset);

            _strategies[_i++] = Strategy({
                strategy: _strategy,
                ipfs: IUWMetadata(_strategy).metadata()
            });
        }
    }
}
