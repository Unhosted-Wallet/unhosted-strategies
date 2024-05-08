// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface WrappedETH is IERC20 {
    function withdraw(uint256 wad) external;
    function deposit() external payable;
}