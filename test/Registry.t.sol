// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../src/UWLidoStrategy.sol";
import "../src/UWStrategyRegistry.sol";

import {Test} from "forge-std/Test.sol";

contract RegistryTest is Test {
    UWStrategyRegistry public registry;

    function setUp() public {
        registry = new UWStrategyRegistry();
    }

    function testAddStrategy() public {
        UWLidoStrategy strategy = new UWLidoStrategy(
            ILido(address(0)),
            IwstETH(address(0)),
            address(0)
        );

        registry.add(address(strategy));

        assertEq(registry.count(), 1);
    }

    function testRemoveStrategy() public {
        UWLidoStrategy strategy = new UWLidoStrategy(
            ILido(address(0)),
            IwstETH(address(0)),
            address(0)
        );

        registry.add(address(strategy));
        registry.remove(address(strategy));

        assertEq(registry.count(), 0);
    }
}
