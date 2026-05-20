// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {MockSY} from "../src/mocks/MockSY.sol";
import {PyIndexHarness} from "../src/harness/PyIndexHarness.sol";
import {UnsafeOracleConsumer} from "../src/mocks/UnsafeOracleConsumer.sol";

contract OracleConsumerOvervaluationTest is Test {
    uint256 internal constant ONE = 1e18;

    MockSY internal sy;
    PyIndexHarness internal pyIndex;
    UnsafeOracleConsumer internal consumer;

    function setUp() public {
        sy = new MockSY(ONE);
        pyIndex = new PyIndexHarness(address(sy));
        consumer = new UnsafeOracleConsumer(address(sy), address(pyIndex));
    }

    function test_unsafeConsumerOvervaluesCollateralWhenSyExchangeRateFallsBelowPyIndex() public {
        uint256 syAmount = 100e18;

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

        // Unsafe consumer values collateral using the floored accounting index.
        uint256 unsafeValue = consumer.unsafeValueUsingPyIndex(syAmount);

        // Safe/recoverable value uses current SY exchangeRate.
        uint256 recoverableValue = consumer.safeValueUsingCurrentExchangeRate(syAmount);

        assertEq(unsafeValue, 110e18);
        assertEq(recoverableValue, 95e18);
        assertEq(unsafeValue - recoverableValue, 15e18);
        assertGt(unsafeValue, recoverableValue);
    }
}