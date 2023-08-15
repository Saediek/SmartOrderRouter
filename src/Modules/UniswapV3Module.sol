//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.0;
import "src/Interfaces/IUniswapV3.sol";

import "src/Interfaces/IWETH.sol";

/**
@notice Abstract:UniswapV3 Adapter used to trade and get Price's in UniswapV3 Protocol
*Modules are contracts used to interact with specific Dexes
*Interactions include SingleSwap,MultiSwap,getPrices
*/

contract UniswapV3Module {
    uint24 public constant poolFee = 3000;
    Router public immutable router;
    Factory public immutable factory;
    address immutable SmartOrderRouter;

    modifier OnlySmartOrderRouter() {
        if (msg.sender != SmartOrderRouter) {
            revert("Caller is S.O.R");
        }
        _;
    }

    constructor(address _SmartOrderrouter, address _factory, address _router) {
        SmartOrderRouter = _SmartOrderrouter;
        factory = Factory(_factory);
        router = Router(_router);
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
    ) external view OnlySmartOrderRouter returns (uint256 _amountOut) {
        address _pool = factory.getPool(_tokenIn, _tokenOut, poolFee);
        if (_pool == address(0)) {
            revert("Pool doesn't exist");
        }
        (uint160 _sqrtPrice, , , , , , ) = IUniswapPool(_pool).slot0();
        _amountOut = SqrtPrice.ToPrice(_sqrtPrice) * _amountIn;

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

    function MultiSwap(
        uint256 _amountIn,
        address[] memory _path,
        uint256 _amountMin
    ) external OnlySmartOrderRouter returns (uint256 _amountOut) {
        bytes memory _encodedData;
        for (uint i; i < _path.length; i++) {
            //encoded data appended to the newly created data || concatenated to the old data
            //(token[i],fee[i],token[i++])append(token[i++],fee[i++],token[i+++])
            _encodedData = abi.encodePacked(
                _encodedData,
                abi.encodePacked(_path[i], poolFee, _path[i++])
            );
        }
        Router.ExactInputParams memory params = Router.ExactInputParams({
            path: _encodedData,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: _amountMin
        });
        _amountOut = router.exactInput(params);
    }

    receive() external payable {}
}
