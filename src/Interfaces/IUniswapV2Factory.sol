//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;

interface IUniswapV2Factory {
    function getPool(address _token0, address _token1, uint24 _fee) external view returns (address _pool);
}
