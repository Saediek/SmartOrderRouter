//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;

interface Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);
}

interface Router {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);

    function exactInput(
        ExactInputParams calldata params
    ) external payable returns (uint256 amountOut);
}

interface IUniswapPool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    function liquidity() external view returns (uint128);

    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    function fee() external view returns (uint24);

    function token0() external view returns (address);

    function token1() external view returns (address);
}

library SqrtPrice {
    function ToPrice(
        uint160 _sqrtPrice
    ) external pure returns (uint256 _price) {
        _price = (_sqrtPrice ** 2 * 1e18) / 2 ** 192;
    }
}
