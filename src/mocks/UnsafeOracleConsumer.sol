// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUnsafeConsumerSY {
    function exchangeRate() external view returns (uint256);
}

interface IUnsafeConsumerPyIndex {
    function pyIndexCurrent() external view returns (uint256);
}

/// @title UnsafeOracleConsumer
/// @notice Toy oracle consumer used to demonstrate an integration mistake:
///         valuing SY-backed collateral with the floored PY accounting index
///         instead of the current recoverable SY exchange rate.
/// @dev This contract is intentionally unsafe. It is a teaching/test harness,
///      not a recommended oracle design.
contract UnsafeOracleConsumer {
    uint256 public constant ONE = 1e18;

    IUnsafeConsumerSY public immutable sy;
    IUnsafeConsumerPyIndex public immutable pyIndex;

    constructor(address sy_, address pyIndex_) {
        require(sy_ != address(0), "zero SY");
        require(pyIndex_ != address(0), "zero PY index");

        sy = IUnsafeConsumerSY(sy_);
        pyIndex = IUnsafeConsumerPyIndex(pyIndex_);
    }

    /// @notice Unsafe valuation path.
    /// @dev This treats the floored PY accounting index as if it were current
    ///      recoverable backing value. This can overvalue collateral when
    ///      current SY exchangeRate falls below pyIndexCurrent.
    function unsafeValueUsingPyIndex(uint256 syAmount) external view returns (uint256) {
        return (syAmount * pyIndex.pyIndexCurrent()) / ONE;
    }

    /// @notice Safer baseline valuation for this toy model.
    /// @dev This values the same SY amount using the current SY exchangeRate.
    function safeValueUsingCurrentExchangeRate(uint256 syAmount) external view returns (uint256) {
        return (syAmount * sy.exchangeRate()) / ONE;
    }

    /// @notice Difference between unsafe accounting-index valuation and
    ///      current recoverable-value valuation.
    function overvaluationAmount(uint256 syAmount) external view returns (uint256) {
        uint256 unsafeValue = (syAmount * pyIndex.pyIndexCurrent()) / ONE;
        uint256 safeValue = (syAmount * sy.exchangeRate()) / ONE;

        if (unsafeValue <= safeValue) {
            return 0;
        }

        return unsafeValue - safeValue;
    }
}