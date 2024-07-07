//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;

interface IUniswapV2Factory {
    function getPair(
        address _token0,
        address _token1
    ) external view returns (address _pool);
}
