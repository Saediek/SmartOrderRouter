// SPDX-License-Identifier: MIT
pragma solidity  ^0.8;

interface IProtocolFeesCollector {
    function getSwapFeePercentage() external view returns (uint256);
}
