// SPDX-License-Identifier: MIT
/// This is developed and simplified based on HLido.sol by Furucombo

pragma solidity 0.8.20;

interface ILido {
    function submit(address _referral) external payable returns (uint256);

    function sharesOf(address _account) external view returns (uint256);

    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);
}

interface ILidoStrategy {
    function submit(uint256 value) external payable returns (uint256 stTokenAmount);
}
