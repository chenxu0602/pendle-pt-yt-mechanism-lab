// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {MockSY} from "../src/mocks/MockSY.sol";
import {PyIndexHarness} from "../src/harness/PyIndexHarness.sol";

contract PyIndexFloorTest is Test {
    uint256 internal constant ONE = 1e18;

    MockSY internal sy;
    PyIndexHarness internal harness;

    function setUp() public {
        sy = new MockSY(ONE);
        harness = new PyIndexHarness(address(sy));
    }

    function test_initialPyIndexEqualsInitialSyExchangeRate() public {
        assertEq(sy.exchangeRate(), ONE);
        assertEq(harness.pyIndexStored(), ONE);
        assertEq(harness.pyIndexCurrent(), ONE);
    }

    function test_pyIndexIncreasesWhenSyExchangeRateIncreases() public {
        sy.setExchangeRate(1.10e18);

        assertEq(sy.exchangeRate(), 1.10e18);

        uint256 currentIndexBeforeUpdate = harness.pyIndexCurrent();
        assertEq(currentIndexBeforeUpdate, 1.10e18);

        harness.updatePyIndex();

        assertEq(harness.pyIndexStored(), 1.10e18);
        assertEq(harness.pyIndexCurrent(), 1.10e18);
    }

    function test_pyIndexDoesNotDecreaseWhenSyExchangeRateFalls() public {
        sy.setExchangeRate(1.10e18);
        harness.updatePyIndex();

        assertEq(harness.pyIndexStored(), 1.10e18);

        sy.setExchangeRate(0.95e18);

        assertEq(sy.exchangeRate(), 0.95e18);
        assertEq(harness.pyIndexStored(), 1.10e18);
        assertEq(harness.pyIndexCurrent(), 1.10e18);
        assertEq(harness.stressGap(), 0.15e18);
    }

    function test_accountingIndexCanDivergeFromRecoverableBacking() public {
        uint256 syAmount = 100e18;

        sy.setExchangeRate(1.10e18);
        harness.updatePyIndex();

        uint256 pyAccountingAmount = harness.syToPY(syAmount);
        assertEq(pyAccountingAmount, 110e18);

        sy.setExchangeRate(0.95e18);

        uint256 assetRecoverableAtCurrentSyRate = (syAmount * sy.exchangeRate()) / ONE;
        uint256 pyAccountingAmountAfterDrop = harness.syToPY(syAmount);

        assertEq(assetRecoverableAtCurrentSyRate, 95e18);
        assertEq(pyAccountingAmountAfterDrop, 110e18);

        assertGt(pyAccountingAmountAfterDrop, assetRecoverableAtCurrentSyRate);
    }
}