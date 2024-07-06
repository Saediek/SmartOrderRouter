/**
 * SPDX-License-Identifier:LICENSED-BY-THE-PEAKY-BLINDERS
 * author:<Saediek>
 */
pragma solidity ^0.8;

interface ICurveRouter {
    function exchange_with_best_rate(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver
    ) external returns (uint256 _amountOut);

    function get_best_rate(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address[8] memory _excludePools
    ) external view returns (address, uint256 _amountOut);
}
