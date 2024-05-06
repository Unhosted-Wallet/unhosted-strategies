// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUWDeposit} from "./interfaces/IUWDeposit.sol";
import {IUWDepositBeneficiary} from "./interfaces/IUWDepositBeneficiary.sol";
import {IUWBorrow} from "./interfaces/IUWBorrow.sol";
import {IUWDebtReport} from "./interfaces/IUWDebtReport.sol";
import {IUWAssetsReport, Asset} from "./interfaces/IUWAssetsReport.sol";
import {UWBaseStrategy} from "./abstract/UWBaseStrategy.sol";
import {UWConstants} from "./libraries/UWConstants.sol";
import {IUWErrors} from "./interfaces/IUWErrors.sol";

interface IComet {
    struct AssetInfo {
        uint8 offset;
        address asset;
        address priceFeed;
        uint64 scale;
        uint64 borrowCollateralFactor;
        uint64 liquidateCollateralFactor;
        uint64 liquidationFactor;
        uint128 supplyCap;
    }

    function supply(address asset, uint amount) external;
    function supplyTo(address dst, address asset, uint amount) external;
    function withdrawTo(address to, address asset, uint amount) external;
    function getAssetInfoByAddress(address asset) external view returns (AssetInfo memory);
    function collateralBalanceOf(address account, address asset) external view returns (uint128);
}

interface wETH is IERC20 {
    function withdraw(uint wad) external;
    function deposit() external payable;
}

contract UWCompoundV3Strategy is IUWDeposit, IUWDepositBeneficiary, IUWBorrow, UWBaseStrategy {
    wETH immutable internal WETH;

    constructor(wETH _weth) {
        WETH = _weth;
    }

    function deposit(bytes32 position, address asset, uint256 amount) external payable override {
       depositTo(position, asset, amount, address(this)); 
    }

    function depositTo(bytes32 position, address asset, uint256 amount, address beneficiary) public payable {
        IComet _comet = IComet(address(uint160(uint256(position))));

        // Handle the native asset and normalize it. 
        if(asset == UWConstants.NATIVE_ASSET){
            // Wrap ETH
            WETH.deposit{value: amount}();
            // Continue as normal but set the token to be used to WETH.
            asset = address(WETH);
        }

        // Approve the asset to be deposited.
        // TODO: Handle the max uint256 scenario.
        IERC20(asset).approve(address(_comet), amount);

        // Perform the deposit.
        _comet.supplyTo(beneficiary, asset, amount);
    }

    function borrow(bytes32 position, address asset, uint256 amount) external override {
       borrowTo(position, asset, amount, address(this));
    }

    function borrowTo(bytes32 position, address asset, uint256 amount, address beneficiary) public override {
        // TODO: Call Compound configurator to check if the amount is within bounds.
        IComet _comet = IComet(address(uint160(uint256(position))));
        // If the asset we are borrowing is an ERC20 we can exit early. 
        if (asset != UWConstants.NATIVE_ASSET) return _comet.withdrawTo(beneficiary, asset, amount);
        // Borrow WETH.
        _comet.withdrawTo(address(this), address(WETH), amount);
        // Unwrap thw WETH.
        WETH.withdraw(amount);
        // Send it to the beneficiary if we are not the beneficiary.
        if(beneficiary != address(this)) WETH.transfer(beneficiary, amount);
    }
    
    receive() external payable {}
}
