// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MockSY
/// @notice Minimal Standardized Yield mock for Pendle-style mechanism experiments.
/// @dev This is intentionally small. It only models exchangeRate and simple SY/accounting conversion.
contract MockSY {
    uint256 public constant ONE = 1e18;

    string public name = "Mock Standardized Yield";
    string public symbol = "MockSY";
    uint8 public decimals = 18;

    /// @notice Asset value per 1 SY, scaled by 1e18.
    /// 1.00 = 1e18, 1.10 = 1.1e18, 0.95 = 0.95e18.
    uint256 public exchangeRate;

    constructor(uint256 initialExchangeRate) {
        require(initialExchangeRate > 0, "exchange rate is zero");
        exchangeRate = initialExchangeRate;
    }

    function setExchangeRate(uint256 newExchangeRate) external {
        require(newExchangeRate > 0, "exchange rate is zero");
        exchangeRate = newExchangeRate;
    }

    function syToAsset(uint256 syAmount) external view returns (uint256) {
        return (syAmount * exchangeRate) / ONE;
    }

    function assetToSy(uint256 assetAmount) external view returns (uint256) {
        return (assetAmount * ONE) / exchangeRate;
    }

    function assetToSyUp(uint256 assetAmount) external view returns (uint256) {
        return (assetAmount * ONE + exchangeRate - 1) / exchangeRate;
    }
}