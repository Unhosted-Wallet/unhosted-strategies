// SPDX-License-Identifier: MIT
/// This is developed and simplified based on HLido.sol by Furucombo

pragma solidity 0.8.20;

import {BaseStrategy} from "src/BaseStrategy.sol";
import {ILido, ILidoStrategy} from "src/lido/ILidoStrategy.sol";

contract LidoStrategy is BaseStrategy, ILidoStrategy {
    address public immutable referral;
    ILido public immutable lidoProxy;

    constructor(address lidoProxy_, address referral_) {
        referral = referral_;
        lidoProxy = ILido(lidoProxy_);
    }

    function submit(
        uint256 value
    ) public payable returns (uint256 stTokenAmount) {
        value = _getBalance(NATIVE_TOKEN_ADDRESS, value);

        try lidoProxy.submit{value: value}(referral) returns (
            uint256 sharesAmount
        ) {
            stTokenAmount = lidoProxy.getPooledEthByShares(sharesAmount);
        } catch Error(string memory reason) {
            _revertMsg("submit", reason);
        } catch {
            _revertMsg("submit");
        }
    }

    function getStrategyName()
        public
        pure
        virtual
        override
        returns (string memory)
    {
        return "Lido";
    }
}
