/**
 * SPDX-License-Identifier:UNLICENSED
 * @author Saediek ||<Saediek@proton.me>
 */
pragma solidity ^0.8;

import "../Interfaces/IAdapter.sol";

abstract contract UniswapV3Adapter is IAdapter {
    string public constant Name = "UNISWAP-V3-ADAPTER";

    function Swap(
        address[] memory _tokens,
        uint256 _amountIn,
        uint256 _minAmountOut,
        bytes memory _data,
        address _receiver
    ) external payable returns (uint256) {}

    function computeAmountOut(
        address[] memory _tokens,
        uint256 _amountIn
    ) external view returns (uint256 _amountOut) {}
}
