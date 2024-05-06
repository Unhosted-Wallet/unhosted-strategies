// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../src/UWLidoStrategy.sol";

import {Test} from "forge-std/Test.sol";

contract LidoStrategyTest is Test {
    ILido LIDO = ILido(address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84));
    IwstETH wstETH = IwstETH(address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0));
    address referral;
    UWLidoStrategy strategy;

    function setUp() public {
        // Configure forking mainnet
        vm.createSelectFork("https://rpc.payload.de");

        vm.label(address(LIDO), "LIDO");
        vm.label(address(wstETH), "wstETH");
        strategy = new UWLidoStrategy(LIDO, wstETH, referral);
    }

    function testDeposit(uint256 amount) public {
        amount = bound(amount, 100 wei, 1000 ether);

        vm.deal(address(strategy), amount);
        strategy.deposit(bytes32(uint256(uint160(address(LIDO)))), UWConstants.NATIVE_ASSET, amount);

        // Check that the assets were updated accordingly
        Asset[] memory assets = strategy.assets(bytes32(uint256(uint160(address(LIDO)))));
        assertApproxEqAbs(assets[0].amount, amount, 100 wei);

        // Check the debt.
        Asset[] memory debts = strategy.debt(bytes32(uint256(uint160(address(LIDO)))));
        assertEq(assets[0].amount, debts[0].amount);
    }

    function testDepositForWstETH(uint256 amount) public {
        amount = bound(amount, 100 wei, 1000 ether);

        vm.deal(address(strategy), amount);
        strategy.deposit(bytes32(uint256(uint160(address(wstETH)))), UWConstants.NATIVE_ASSET, amount);

        // Check that the assets were updated accordingly
        Asset[] memory assets = strategy.assets(bytes32(uint256(uint160(address(wstETH)))));
        assertApproxEqAbs(assets[0].amount, amount, 100 wei);

        // Check the debt.
        Asset[] memory debts = strategy.debt(bytes32(uint256(uint160(address(wstETH)))));
        assertEq(assets[0].amount, LIDO.getPooledEthByShares(wstETH.getStETHByWstETH(debts[0].amount)));
    }

    function testDeposit_amountBelowBound_reverts() public {
        vm.deal(address(strategy), 10 ether);

        // TODO: vm.expectRevert(IUWErrors.ASSET_AMOUNT_OUT_OF_BOUNDS.selector);
        vm.expectRevert();
        strategy.deposit(bytes32(uint256(uint160(address(wstETH)))), UWConstants.NATIVE_ASSET, 99 wei);
    }
}
