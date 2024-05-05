// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {ILido, UWLidoStrategy} from "../src/UWLidoStrategy.sol";

import {Test} from "forge-std/Test.sol";

contract LidoStrategyTest is Test {
    ILido LIDO;
    address wstETH;
    address referral;
    UWLidoStrategy strategy;

    function setUp() public {
        strategy = new UWLidoStrategy(LIDO, wstETH, referral);
    }

    function testNothing() public {}
}
