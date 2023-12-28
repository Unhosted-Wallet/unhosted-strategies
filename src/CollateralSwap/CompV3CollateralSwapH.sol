// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CompoundV3Handler} from "@unhosted/handlers/compoundV3/CompoundV3H.sol";
import {BaseHandler, IERC20, SafeERC20} from "@unhosted/handlers/BaseHandler.sol";
import {UniswapV3Handler} from "@unhosted/handlers/uniswapV3/UniswapV3H.sol";
import {AaveV2Handler, ILendingPoolAddressesProviderV2} from "@unhosted/handlers/aaveV2/AaveV2H.sol";
import {IComet} from "@unhosted/handlers/compoundV3/IComet.sol";

contract CompV3CollateralSwap is UniswapV3Handler, CompoundV3Handler, AaveV2Handler {
    using SafeERC20 for IERC20;

    address private immutable _fallbackHandler;

    constructor(address wethAddress, address uniV3Router, address aaveV2Provider, address fallbackHandler)
        CompoundV3Handler(wethAddress)
        UniswapV3Handler(wethAddress, uniV3Router)
        AaveV2Handler(wethAddress, aaveV2Provider, fallbackHandler)
    {
        _fallbackHandler = fallbackHandler;
    }

    struct ReceiveData {
        address tokenOut;
        address comet;
    }

    function collateralSwap(
        address comet,
        address _currentCollateralToken,
        address _newCollateralToken,
        uint256 _amountToSwap,
        uint256 _mode
    ) public payable {
        uint256[] memory mode = new uint256[](1);
        uint256[] memory amount = new uint256[](1);
        address[] memory token = new address[](1);
        ReceiveData memory receiveData = ReceiveData(_newCollateralToken, comet);
        mode[0] = _mode;
        amount[0] = _amountToSwap;
        token[0] = _currentCollateralToken;
        bytes memory data = abi.encode(receiveData);

        IComet(comet).allow(_fallbackHandler, true);
        IERC20(_currentCollateralToken).approve(_fallbackHandler, _amountToSwap);
        flashLoan(token, amount, mode, data);
        IComet(comet).allow(_fallbackHandler, false);
        IERC20(_currentCollateralToken).approve(_fallbackHandler, 0);
    }

    function getContractName()
        public
        pure
        override(UniswapV3Handler, CompoundV3Handler, AaveV2Handler)
        returns (string memory)
    {
        return "CollateralSwapStrategy";
    }
}
