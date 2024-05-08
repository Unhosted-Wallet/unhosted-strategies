// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

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

    struct UserBasic {
        int104 principal;
        uint64 baseTrackingIndex;
        uint64 baseTrackingAccrued;
        uint16 assetsIn;
        uint8 _reserved;
    }

    struct UserCollateral {
        uint128 balance;
        uint128 _reserved;
    }

    struct TotalsBasic {
        uint64 baseSupplyIndex;
        uint64 baseBorrowIndex;
        uint64 trackingSupplyIndex;
        uint64 trackingBorrowIndex;
        uint104 totalSupplyBase;
        uint104 totalBorrowBase;
        uint40 lastAccrualTime;
        uint8 pauseFlags;
    }

    function supply(address asset, uint256 amount) external;
    function supplyTo(address dst, address asset, uint256 amount) external;
    function withdrawTo(address to, address asset, uint256 amount) external;
    function getAssetInfo(uint8 i) external view returns (AssetInfo memory);
    function getAssetInfoByAddress(address asset) external view returns (AssetInfo memory);
    function getPrice(address feed) external view returns (uint256);
    function collateralBalanceOf(address account, address asset) external view returns (uint128);
    function baseToken() external view returns (address);
    function baseScale() external view returns (uint256);
    function baseTokenPriceFeed() external view returns (address);
    function baseBorrowMin() external view returns (uint256);
    function borrowBalanceOf(address account) external view returns (uint256);
    function totalsBasic() external view returns (TotalsBasic memory);
    function userBasic(address user) external view returns (UserBasic memory);
    function userCollateral(address user, address collateral) external view returns (UserCollateral memory);
    function numAssets() external view returns (uint8);
}
