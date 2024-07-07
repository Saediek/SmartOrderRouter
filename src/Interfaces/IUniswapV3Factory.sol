/**
 * SPDX-License-Identifier:UNLICENSED
 * @author Saediek ||<Saediek@proton.me>
 */
pragma solidity ^0.8;

interface IUniswapFactory {
    function getPool(
        address _token0,
        address _token1,
        uint24 _fee
    ) external view returns (address);
}
