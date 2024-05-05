// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { IUWDeposit } from "./interfaces/IUWDeposit.sol";
import { UWBaseStrategy } from "./abstract/UWBaseStrategy.sol";
import { UWConstants} from "./libraries/UWConstants.sol";
import { IUWErrors } from "./interfaces/IUWErrors.sol";
interface ILido {
    function submit(address _referral) external payable returns (uint256);
}

interface IwstETH {
    function wrap(uint256 _stETHAmount) external returns (uint256); 
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
}

contract UWLidoStrategy is IUWDeposit, UWBaseStrategy {
    ILido immutable LIDO;
    address immutable wstETH;
    address immutable referral;

    constructor(ILido _lido, address _wstETH, address _referral) {
       LIDO = _lido; 
       wstETH = _wstETH;
       referral = _referral;
    }

    function deposit(bytes32 position, address asset, uint256 amount) external payable override {
        // Only native Ether is supported.
        if(asset != UWConstants.NATIVE_ASSET) revert IUWErrors.UNSUPPORTED_ASSET(asset);
        // Check that the position is one of the two available options.  
        if(address(uint160(uint256(position))) != address(LIDO) && address(uint160(uint256(position))) != wstETH)
            revert IUWErrors.INVALID_POSITION(position);
        
        // Check that the amount to deposit is within the allowed bound of Lido and that the user has enough balance 
        if(amount < 100 wei || amount > address(this).balance || amount > 1000 ether)
            revert IUWErrors.ASSET_AMOUNT_OUT_OF_BOUNDS(
                asset,
                100 wei,
                address(this).balance < 1000 ether ? address(this).balance : 1000 ether,
                amount
            );
       
        uint256 _receivedAmount = LIDO.submit{value: amount}(referral);
       
    }
}
