/**
 * SPDX-License-Identifier:UNLICENSED
 * @author:<Saediek>
 */
//Gateway to trade on uniswap
pragma solidity ^0.8;
import "../Interfaces/IZeroEx.sol";
import "../Interfaces/IAdapter.sol";

contract ZeroExAdapter is IAdapter {
    string public Name = "ZERO-EX-ADAPTER";
    address private executor;

    constructor(address _exchangeProxy) {}

    function Swap(
        address[] memory _tokens,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        bool _uniswap
    ) external payable returns (uint256) {}

    function computeAmountOut(
        address[] memory _tokens,
        uint256 _amountIn,
        bool _reroute
    ) external view returns (uint256 _amountOut) {}
}
