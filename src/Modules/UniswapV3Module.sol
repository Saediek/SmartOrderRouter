//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.0;
import "src/Interfaces/IUniswapV3.sol";

import "src/Interfaces/IWETH.sol";
import "src/Interfaces/IERC20.sol";
import "src/Libraries/SafeERC20.sol";

/**
@notice Abstract:UniswapV3 Adapter used to trade and get Price's in UniswapV3 Protocol
*Modules are contracts used to interact with specific Dexes
*Interactions include SingleSwap,MultiSwap,getPrices
*/
//@todo Price Multi-Swap
//

contract UniswapV3Module {
    using SafeERC20 for IERC20;
    uint24 public constant poolFee = 3000;
    Router public immutable router;
    Factory public immutable factory;
    address immutable SmartOrderRouter;
    address immutable flashloanModule;

    modifier OnlySmartOrderRouter() {
        if (msg.sender != SmartOrderRouter) {
            revert("Caller is !S.O.R");
        }
        _;
    }

    constructor(
        address _SmartOrderrouter,
        address _factory,
        address _router,
        address _flashloanModule
    ) {
        SmartOrderRouter = _SmartOrderrouter;
        factory = Factory(_factory);
        router = Router(_router);
        flashloanModule = _flashloanModule;
    }

    /**
    * @notice get Price of pair token1 in terms of token2
      @param _tokenIn: token a trader is offering for the trade
      @param _tokenOut:Receiving token for the trade
      @param _amountIn:The  _tokenIn amount a  user is offering for a trade
     
      @return return the amount of _tokenOut a user would get if _amountIn of _tokenIn is traded
      @Price of a token0 in terms of token1 ==1.0001^tick{i.e Price is gotten from the last 60 seconds} in preciseUnit
     */
    ///=========GETTERS=========///
    ///=========================///

    function getPrice(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) public view returns (uint256 _amountOut) {
        address _pool = factory.getPool(_tokenIn, _tokenOut, poolFee);
        if (_pool == address(0)) {
            return 0;
        }
        (, int24 _tick, , , , , ) = IUniswapPool(_pool).slot0();

        _amountOut = UniswapLibrary.getQuoteAtTick(
            _tick,
            uint128(_amountIn),
            _tokenIn,
            _tokenOut
        );

        //1.0001^tick=price of token*_amountIn
        //Price=(sqrtPrice/2^96)^2
    }

    /**
    SINGLE-SWAP(WRITE && READ METHOD) that swaps tokenIn directly to tokenOut (specified)
    there are no intermediaries tokens in this method
    @param _tokenIn: Address  of the token thats is being traded for tokenOut
    @param _tokenOut:Address of token that is being received from the trade
    @param _amountIn: Amount of tokenIn the user is willing trade
    @param _amountOutMin:Minimum amount of _tokenOut a user is willing to accept from the trade
    @return _amountOut The amount of the tokenOut received from the trade
     */
    //========WRITE-METHODS=============//
    //==================================//

    function SingleSwap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external payable OnlySmartOrderRouter returns (uint256 _amountOut) {
        IERC20(_tokenIn).approve(address(router), _amountIn);
        Router.ExactInputSingleParams memory _params = Router
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: _amountOutMin,
                sqrtPriceLimitX96: 0
            });
        _amountOut = router.exactInputSingle(_params);
    }

    /**
    *notice Just like SingleSwap but has intermediaries, this mean it doesn't just swap tokenIn for tokenOut
    given a list of intermediary addresses it trades _path[i]-->path[i++] and keeps trading till there is no intermediary left out
    *Note:  Very long path is more likely to result in out of gas errors than shorter paths.
    @param _amountIn:The amount of the first path(i.e path[0]) a users is willing to trade
    @param _path:An array of intermediary paths a swap should go through {Note:Should be kept minimal to avoid 
    out of gas errors}
    @param _amountMin: Minimum amount of the last path  a user is willing to receive 
    @return _amountOut The amount of the last path received from the trade
    * remind We need to create  a data in the format {tokenIn ,fee, tokenOut}
     */

    function multiSwap(
        uint256 _amountIn,
        address[] memory _path,
        uint256 _amountMin
    ) external OnlySmartOrderRouter returns (uint256 _amountOut) {
        IERC20(_path[0]).safeApprove(address(router), _amountIn);
        bytes memory _encodedData = "";
        for (uint8 i; i < _path.length - 1; i++) {
            _encodedData = abi.encodePacked(
                _encodedData,
                abi.encodePacked(_path[i], poolFee)
            );
        }

        _encodedData = abi.encodePacked(_encodedData, _path[_path.length - 1]);
        Router.ExactInputParams memory params = Router.ExactInputParams({
            path: _encodedData,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: _amountMin
        });
        _amountOut = router.exactInput(params);
    }

    function flashloan(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _payload,
        address caller
    ) external {
        _payload = abi.encodePacked(_payload, caller);
        address _pool = factory.getPool(_tokens[0], _tokens[1], poolFee);
        IUniswapPool(_pool).flash(
            flashloanModule,
            _amounts[0],
            _amounts[1],
            _payload
        );
    }

    /**
     * One approach to get price for a multi-swap is to get individual swaps amountOut for each pair
     *while this approach would take 0(n) time so it is not reliable.
     */
    //@todo Implement pricing mechanism for multi-swap.

    function getPriceMulti(
        address[] memory _tokens,
        uint _amountIn
    ) external view returns (uint256 _amountOut) {
        for (uint i; i < _tokens.length; i++) {
            if (i == 0) {
                _amountIn = getPrice(_tokens[i], _tokens[i + 1], _amountIn);
            } else {
                _amountIn = getPrice(_tokens[i], _tokens[i + 1], _amountIn);
            }
        }
        _amountOut = _amountIn;
    }

    receive() external payable {}

    fallback() external payable {}
}
