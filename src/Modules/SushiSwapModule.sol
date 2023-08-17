//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.0;
import "src/Interfaces/IUniswapV2.sol";

/**
@notice Abstract:UniswapV2 adapter used to perform trades{SingleSwap,MultiSwap}and fetch prices tokens from a pool


 */

contract PancakeModule {
    address immutable Sushi_factory;
    IUniswapV2Router Sushi_Router;
    address immutable SmartOrderRouter;
    modifier OnlySmartOrderRouter() {
        require(
            msg.sender == SmartOrderRouter,
            "Caller is not the smart order router"
        );
        _;
    }

    constructor(address _router, address _factory, address _smartOrderRouter) {
        Sushi_Router = IUniswapV2Router(_router);
        Sushi_factory = _factory;
        SmartOrderRouter = _smartOrderRouter;
    }

    /**

    * @notice Used to get the price of one tokens in terms of the other token.
    * @param _token1:The token you want to trade for
    * @param _token2 The token you want in return 
      @notice returns the price of a token in terms of the other token

     */
    function getPrice(
        address _token1,
        address _token2,
        uint256 _amount
    ) external view returns (uint256 _price) {
        (uint256 _reserves1, uint256 _reserves2) = UniswapV2Library.getReserves(
            address(Sushi_Router),
            _token1,
            _token2
        );
        _price = Sushi_Router.getAmountOut(_amount, _reserves1, _reserves2);
    }

    function SingleSwap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external returns (uint256 _swapAmount) {
        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;

        uint256[] memory _AmountsOut = Sushi_Router.swapExactTokensForTokens(
            _amountIn,
            _amountOutMin,
            path,
            msg.sender,
            block.timestamp
        );

        _swapAmount = _AmountsOut[0];
        require(_swapAmount >= _amountOutMin, "Min amount not exceeded");
    }

    function MultiSwap(
        uint256 _amountIn,
        address[] memory _path,
        uint256 _minOut
    ) external returns (uint256 _swapAmountOut) {
        uint256[] memory _amountsOut = Sushi_Router.swapExactTokensForTokens(
            _amountIn,
            _minOut,
            _path,
            msg.sender,
            block.timestamp
        );
        _swapAmountOut = _amountsOut[_amountsOut.length - 1];
    }
}
