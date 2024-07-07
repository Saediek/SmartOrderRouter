/**
 * SPDX-License-Identifier:UNLICENSED
 */
pragma solidity ^0.8;

interface IUniswapV3 {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(
        ExactInputParams calldata params
    ) external payable returns (uint256 amountOut);
}

interface IUniswapFactory {
    function getPool(
        address _token0,
        address _token1,
        uint24 _fee
    ) external view returns (address);
}
