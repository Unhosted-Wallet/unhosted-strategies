// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @notice Includes helper functions ripped from different contracts in Comet instead.
/// of copying whole contracts. Also includes error definitions, events, and constants.
contract CometHelpers {
    uint64 internal constant FACTOR_SCALE = 1e18;
    uint64 internal constant BASE_INDEX_SCALE = 1e15;
    uint64 internal constant BASE_ACCRUAL_SCALE = 1e6;

    error InvalidUInt104();
    error InvalidInt256();
    error NegativeNumber();

    /**
     * @dev The positive present supply balance if positive or the negative borrow balance if negative
     */
    function presentValue(
        int104 principalValue_,
        uint64 _baseSupplyIndex,
        uint64 _baseBorrowIndex
    ) internal pure returns (int256) {
        if (principalValue_ >= 0) {
            return
                signed256(
                    presentValueSupply(
                        _baseSupplyIndex,
                        uint104(principalValue_)
                    )
                );
        } else {
            return
                -signed256(
                    presentValueBorrow(
                        _baseBorrowIndex,
                        uint104(-principalValue_)
                    )
                );
        }
    }

    /// @dev Multiply a number by a factor
    /// https://github.com/compound-finance/comet/blob/main/contracts/Comet.sol#L681-L683
    function mulFactor(
        uint256 n,
        uint256 factor
    ) internal pure returns (uint256) {
        return (n * factor) / FACTOR_SCALE;
    }

    /// @dev The principal amount projected forward by the supply index
    /// From https://github.com/compound-finance/comet/blob/main/contracts/CometCore.sol#L83-L85
    function presentValueSupply(
        uint64 baseSupplyIndex_,
        uint256 principalValue_
    ) internal pure returns (uint256) {
        return (principalValue_ * baseSupplyIndex_) / BASE_INDEX_SCALE;
    }

    /**
     * @dev The principal amount projected forward by the borrow index
     */
    function presentValueBorrow(
        uint64 baseBorrowIndex_,
        uint104 principalValue_
    ) internal pure returns (uint256) {
        return (uint256(principalValue_) * baseBorrowIndex_) / BASE_INDEX_SCALE;
    }

    /// @dev The present value projected backward by the supply index (rounded down)
    /// Note: This will overflow (revert) at 2^104/1e18=~20 trillion principal for assets with 18 decimals.
    /// From https://github.com/compound-finance/comet/blob/main/contracts/CometCore.sol#L109-L111
    function principalValueSupply(
        uint64 baseSupplyIndex_,
        uint256 presentValue_
    ) internal pure returns (uint104) {
        return safe104((presentValue_ * BASE_INDEX_SCALE) / baseSupplyIndex_);
    }

    function safe104(uint256 n) internal pure returns (uint104) {
        if (n > type(uint104).max) revert InvalidUInt104();
        return uint104(n);
    }

    function signed256(uint256 n) internal pure returns (int256) {
        if (n > uint256(type(int256).max)) revert InvalidInt256();
        return int256(n);
    }

    function unsigned256(int256 n) internal pure returns (uint256) {
        if (n < 0) revert NegativeNumber();
        return uint256(n);
    }
}
