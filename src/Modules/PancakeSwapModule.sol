//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.0;
import "src/Interfaces/IUniswapV2.sol";
import "src/Interfaces/IERC20.sol";
import "src/Libraries/SafeERC20.sol";

/**
* Abstract:Pancake Dex Module used to getPrice of pair(i.e token1/token2),perform Multiswap and Single Swap

 */

contract UniswapV2Modules {
    using SafeERC20 for *;
    address immutable Pancake_factory;
    IUniswapV2Router Pancake_Router;
    address immutable SmartOrderRouter;

    /**
     *Initialize the pancake Router and the pancake Factory,smartOrderRouter
     */

    constructor(address _router, address _factory, address _smartOrderRouter) {
        Pancake_Router = IUniswapV2Router(_router);
        Pancake_factory = _factory;
        SmartOrderRouter = _smartOrderRouter;
    }

    modifier OnlySmartOrderRouter() {
        require(
            msg.sender == SmartOrderRouter,
            "Caller is not the smart order router"
        );
        _;
    }

    /**

    * @notice Used to get the price of  _token1 in terms of the other token.
    * @param _token1:The token you want to trade for
    * @param _token2 The token you want in return 
      @notice returns the price of a token in terms of the other token

     */
    function getPrice(
        address _token1,
        address _token2,
        uint256 _amount
    ) external view OnlySmartOrderRouter returns (uint256 _price) {
        (uint256 _reserves1, uint256 _reserves2) = UniswapV2Library.getReserves(
            Pancake_factory,
            _token1,
            _token2
        );
        _price = Pancake_Router.getAmountOut(_amount, _reserves1, _reserves2);
    }

    /**
     *Single Swap:Method that swaps _tokenIn-->_tokenOut within the constraint of _amountOutMin
     *@param  _tokenIn :The address of the token that the user wants to trade
     *@param _tokenOut :The address of the token that the user is receiving || trading for.
     *@param _amountIn: The amount of _tokenIn the user is willing to offer for the trade
     *@param _amountOutMin : The minimum acceptable amount of _tokenOut a user is willing to receive
     *@return _amountOut : The amount of _tokenOut the user would receive
     */

    function SingleSwap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external OnlySmartOrderRouter returns (uint256 _amountOut) {
        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;
        IERC20(_tokenIn).safeApprove(address(Pancake_Router), _amountIn);

        uint256[] memory _AmountsOut = Pancake_Router.swapExactTokensForTokens(
            _amountIn,
            _amountOutMin,
            path,
            msg.sender,
            block.timestamp
        );
        require(
            _AmountsOut[0] >= _amountOutMin,
            "AmountOut does not exceed Min"
        );
        _amountOut = _AmountsOut[0];
        IERC20(_tokenIn).safeApprove(address(Pancake_Router), 0);
    }

    /**
    *MultiSwap: Method for trading an ERC20 token for a path of tokens, more like SingleSwap but has intermediaries 
    *In SingleSwap TokenIn are traded for TokenOut, while MultiSwap Token[i]-->Token[i++]....Token[n-1] where n is the length of
    *the path.
    *@param _amountIn: The amount of Token[i]{The first index in path}
    @param _path : An array  of token addresses that are traded sequential i.e {Token[i]-->Token[i++]....Token[n-1}
    @param _minOut : The Minimum amount of acceptable Token[n-1] the user is willing to accept
    @return _swapAmountOut :The amount of Token[n-1] received by the user from  the trade 
    * Extra scope to prevent stack to deep.

     */

    function MultiSwap(
        uint256 _amountIn,
        address[] memory _path,
        uint256 _minOut
    ) external OnlySmartOrderRouter returns (uint256 _swapAmountOut) {
        {
            IERC20(_path[0]).safeApprove(address(Pancake_Router), _amountIn);
            uint256[] memory _amountsOut = Pancake_Router
                .swapExactTokensForTokens(
                    _amountIn,
                    _minOut,
                    _path,
                    msg.sender,
                    block.timestamp
                );
            _swapAmountOut = _amountsOut[_amountsOut.length - 1];
            IERC20(_path[0]).safeApprove(address(Pancake_Router), 0);
        }
    }
}
