//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.0;
import "src/Interfaces/IUniswapV2.sol";
import "src/Interfaces/IERC20.sol";
import "src/Libraries/SafeERC20.sol";

/**
 * Abstract:UniswapV2 Module:Interactions with UNISWAPV2 CONTRACT:includes FETCH-QUOTE-PRICE,SINGLE-SWAP,MULTI-SWAP
 */

contract UniswapV2Module {
    using SafeERC20 for IERC20;
    //=====VARIABLES=========//
    //=======================//
    address immutable factory;
    address immutable flashloanModule;
    IUniswapV2Router immutable ROUTER;
    address immutable SmartOrderRouter;

    modifier OnlySmartOrderRouter() {
        if (msg.sender != SmartOrderRouter) {
            revert("unrecognised caller");
        }

        _;
    }

    constructor(
        address _router,
        address _factory,
        address _SOR,
        address _flashloanModule
    ) {
        ROUTER = IUniswapV2Router(_router);
        factory = _factory;
        SmartOrderRouter = _SOR;
        flashloanModule = _flashloanModule;
    }

    //=========VIEW-METHODS=========//
    //==============================//
    /**
    *GET-PRICE(READ-METHOD)-Gets the price of _amount of _token1 in terms of _token2
    * @notice Used to get the price of one token in terms of the other token.
    * @param _token1:The token you want to trade 
    * @param _token2 The token you want in return 
      @notice returns the price of a token in terms of the other token

     */

    function getPrice(
        address _token1,
        address _token2,
        uint256 _amount
    ) external view returns (uint256 _price) {
        (uint256 _reserves1, uint256 _reserves2) = UniswapV2Library.getReserves(
            factory,
            _token1,
            _token2
        );
        _price = ROUTER.getAmountOut(_amount, _reserves1, _reserves2);
    }

    //============WRITE-METHODS======//
    //===============================//
    /**
     *Single-Swap METHOD:Trades _amountIn of _tokenIn for _tokenOut within the constraint of _minOut
     *@param _amountIn :Amount of _tokenIn a user is willing to trade for _tokenOut
     *@param _tokenIn  :Address of token being traded
     *@param _tokenOut :Address of token being traded for.
     *@param _minOut   :Minimum acceptable amount of _tokenOut a user is willing to receive
     */
    function singleSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _minOut
    ) external OnlySmartOrderRouter returns (uint256 _swapAmount) {
        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;
        uint256 _length = path.length - 1;

        uint256[] memory _AmountsOut = ROUTER.swapExactTokensForTokens(
            _amountIn,
            _minOut,
            path,
            msg.sender,
            block.timestamp
        );
        _swapAmount = _AmountsOut[_length];
    }

    /**
     *MULTI-SWAP(METHOD)-For Trading _path[i]-->path[++i]--path[n-1]{where i>=0 and n is the length of the route}
     *@param _amountIn : The amount of the genesis path || amount of path[0] a user is willing to trade
     *@param _path     : The Trade route || array of tokens route a trade would go through
     *@param _minOut   : The minimum amount of _path[lastIndex] the user is willing to accept
     */

    function multiSwap(
        uint256 _amountIn,
        address[] memory _path,
        uint256 _minOut
    ) external OnlySmartOrderRouter returns (uint256 _swapAmountOut) {
        uint256[] memory _amountsOut = ROUTER.swapExactTokensForTokens(
            _amountIn,
            _minOut,
            _path,
            msg.sender,
            block.timestamp
        );
        uint8 _length = uint8(_amountsOut.length - 1);
        _swapAmountOut = _amountsOut[_length];
    }

    function flashloan(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _payload,
        address caller
    ) external {
        _payload = abi.encodePacked(_payload, caller);
        address pair = UniswapV2Library.pairFor(
            factory,
            _tokens[0],
            _tokens[1]
        );
        IUniswapV2Pair(pair).swap(
            _amounts[0],
            _amounts[1],
            flashloanModule,
            _payload
        );
    }

    fallback() external payable {
        if (msg.sender != SmartOrderRouter) {
            revert("unrecognised caller");
        }
    }

    receive() external payable {
        if (msg.sender != SmartOrderRouter) {
            revert("unrecognised caller");
        }
    }
}
