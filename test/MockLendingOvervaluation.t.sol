// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {MockSY} from "../src/mocks/MockSY.sol";
import {PyIndexHarness} from "../src/harness/PyIndexHarness.sol";
import {UnsafeOracleConsumer} from "../src/mocks/UnsafeOracleConsumer.sol";
import {MockLendingProtocol} from "../src/mocks/MockLendingProtocol.sol";

contract MockLendingOvervaluationTest is Test {
    uint256 internal constant ONE = 1e18;

    address internal attacker = address(0xA11CE);

    MockSY internal sy;
    PyIndexHarness internal pyIndex;
    UnsafeOracleConsumer internal oracleConsumer;
    MockLendingProtocol internal lending;

    function setUp() public {
        sy = new MockSY(ONE);
        pyIndex = new PyIndexHarness(address(sy));
        oracleConsumer = new UnsafeOracleConsumer(address(sy), address(pyIndex));

        // 80% LTV
        lending = new MockLendingProtocol(address(oracleConsumer), 8_000);
    }

    function test_unsafePyIndexValuationAllowsExcessBorrowingAfterSyImpairment() public {
        uint256 syCollateral = 100e18;

        // Step 1: SY exchangeRate rises from 1.00 to 1.10.
        sy.setExchangeRate(1.10e18);
        pyIndex.updatePyIndex();

        assertEq(sy.exchangeRate(), 1.10e18);
        assertEq(pyIndex.pyIndexStored(), 1.10e18);

        // Step 2: SY exchangeRate falls from 1.10 to 0.95.
        // PY index remains floored at 1.10.
        sy.setExchangeRate(0.95e18);

        assertEq(sy.exchangeRate(), 0.95e18);
        assertEq(pyIndex.pyIndexCurrent(), 1.10e18);

        // Step 3: Attacker deposits 100 SY-equivalent collateral.
        vm.prank(attacker);
        lending.depositCollateral(syCollateral);

        // Unsafe valuation uses floored PY index:
        // 100 * 1.10 = 110
        uint256 unsafeCollateralValue = lending.unsafeCollateralValue(attacker);

        // Safe recoverable valuation uses current SY exchangeRate:
        // 100 * 0.95 = 95
        uint256 safeCollateralValue = lending.safeRecoverableCollateralValue(attacker);

        assertEq(unsafeCollateralValue, 110e18);
        assertEq(safeCollateralValue, 95e18);

        // With 80% LTV:
        // unsafe borrow limit = 110 * 80% = 88
        // safe borrow limit   = 95  * 80% = 76
        uint256 unsafeBorrowLimit = lending.unsafeBorrowLimit(attacker);
        uint256 safeBorrowLimit = lending.safeBorrowLimit(attacker);

        assertEq(unsafeBorrowLimit, 88e18);
        assertEq(safeBorrowLimit, 76e18);
        assertEq(unsafeBorrowLimit - safeBorrowLimit, 12e18);

        // Step 4: Attacker borrows up to the unsafe limit.
        vm.prank(attacker);
        lending.borrowUnsafe(unsafeBorrowLimit);

        assertEq(lending.debtAmount(attacker), 88e18);

        // Under current recoverable-value accounting, the account is undercollateralized.
        assertTrue(lending.isUndercollateralizedUsingSafeValue(attacker));
    }
}