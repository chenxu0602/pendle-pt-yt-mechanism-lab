// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILendingOracleConsumer {
    function unsafeValueUsingPyIndex(uint256 syAmount) external view returns (uint256);
    function safeValueUsingCurrentExchangeRate(uint256 syAmount) external view returns (uint256);
}

/// @title MockLendingProtocol
/// @notice Toy lending protocol used to demonstrate how an unsafe oracle consumer
///         can overvalue SY-backed collateral when PY index remains above current
///         SY exchangeRate.
/// @dev This is intentionally simplified. It does not model real token transfers,
///      liquidations, interest, or multiple users. The goal is to isolate the
///      collateral valuation error.
contract MockLendingProtocol {
    uint256 public constant ONE = 1e18;
    uint256 public constant BPS = 10_000;

    ILendingOracleConsumer public immutable oracleConsumer;

    /// @notice Loan-to-value in basis points.
    /// Example: 8000 = 80%.
    uint256 public immutable ltvBps;

    mapping(address => uint256) public collateralSyAmount;
    mapping(address => uint256) public debtAmount;

    event DepositCollateral(address indexed user, uint256 syAmount);
    event Borrow(address indexed user, uint256 amount);

    constructor(address oracleConsumer_, uint256 ltvBps_) {
        require(oracleConsumer_ != address(0), "zero oracle consumer");
        require(ltvBps_ <= BPS, "ltv too high");

        oracleConsumer = ILendingOracleConsumer(oracleConsumer_);
        ltvBps = ltvBps_;
    }

    /// @notice Deposit SY-denominated collateral.
    /// @dev This mock only records accounting balances. It does not transfer tokens.
    function depositCollateral(uint256 syAmount) external {
        require(syAmount > 0, "zero collateral");

        collateralSyAmount[msg.sender] += syAmount;

        emit DepositCollateral(msg.sender, syAmount);
    }

    /// @notice Unsafe collateral value using the PY accounting index.
    function unsafeCollateralValue(address user) public view returns (uint256) {
        return oracleConsumer.unsafeValueUsingPyIndex(collateralSyAmount[user]);
    }

    /// @notice Safer baseline collateral value using current SY exchangeRate.
    function safeRecoverableCollateralValue(address user) public view returns (uint256) {
        return oracleConsumer.safeValueUsingCurrentExchangeRate(collateralSyAmount[user]);
    }

    /// @notice Borrow limit using unsafe PY-index-based valuation.
    function unsafeBorrowLimit(address user) public view returns (uint256) {
        return (unsafeCollateralValue(user) * ltvBps) / BPS;
    }

    /// @notice Borrow limit using current recoverable-value valuation.
    function safeBorrowLimit(address user) public view returns (uint256) {
        return (safeRecoverableCollateralValue(user) * ltvBps) / BPS;
    }

    /// @notice Excess borrow capacity created by unsafe valuation.
    function excessBorrowCapacity(address user) external view returns (uint256) {
        uint256 unsafeLimit = unsafeBorrowLimit(user);
        uint256 safeLimit = safeBorrowLimit(user);

        if (unsafeLimit <= safeLimit) {
            return 0;
        }

        return unsafeLimit - safeLimit;
    }

    /// @notice Borrow using the unsafe PY-index-based valuation.
    /// @dev This intentionally models a vulnerable external integration.
    function borrowUnsafe(uint256 amount) external {
        require(amount > 0, "zero borrow");

        uint256 newDebt = debtAmount[msg.sender] + amount;
        require(newDebt <= unsafeBorrowLimit(msg.sender), "exceeds unsafe borrow limit");

        debtAmount[msg.sender] = newDebt;

        emit Borrow(msg.sender, amount);
    }

    /// @notice Whether the account is undercollateralized using safe/recoverable valuation.
    function isUndercollateralizedUsingSafeValue(address user) external view returns (bool) {
        return debtAmount[user] > safeBorrowLimit(user);
    }
}