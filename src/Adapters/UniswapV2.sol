//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;

import "../Interfaces/IAdapter.sol";
import "../Interfaces/IUniswapv2.sol";
import "../Interfaces/IUniswapV2Factory.sol";
import {IERC20, SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

/**
 * @title UNISWAP-V2-ADAPTER
 * @author <Saediek ||Saediek@proton.me>
 * UniswapV2 common-tokens list includes=[USDC,USDT,WETH,WBTC,DAI]
 * A Generated Route could exist  ->[tokenIn,COMMON-TOKENS[X],COMMON-TOKEN[Y],tokenOut] || [tokenIn,COMMON-TOKENS[X],tokenOut]
 * Such that there exists a pool of route[x],route[y] where x and y is less than 4 and either tokenIn,tokenOut or a common-token..
 */
contract Uniswap2Adapter is IAdapter {
    using SafeERC20 for uint256;
    //uniswap-v2 only uses the 0.3% fee tier
    uint256 constant feeTier = 3000;

    string public constant Name = "UNISWAP-V2-ADAPTER";
    AdapterState adapterState;

    IUniswapV2 public immutable ROUTER;
    IUniswapV2Factory public immutable FACTORY;

    modifier onlyAdapterOperator() {
        require(adapterState.adapterOperator == msg.sender);
        _;
    }

    constructor(address _router, address _factory) {
        ROUTER = IUniswapV2(_router);
        FACTORY = IUniswapV2Factory(_factory);
    }

    function Swap(
        address[] memory _tokens,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        bool _reroute
    ) external payable returns (uint256) {
        return _swap(_tokens, _amountIn, _minAmountOut, _receiver, _reroute);
    }

    function computeAmountOut(
        address[] memory _tokens,
        uint256 _amountIn,
        bool _reroute
    ) external view returns (uint256 _amountOut) {
        uint256 _lastIndex = _tokens.length - 1;
        if (_reroute) {
            _tokens = _getRoute(_tokens[0], _tokens[_lastIndex]);
        }
        uint256[] memory _amountsOut = ROUTER.getAmountsOut(_amountIn, _tokens);

        _amountOut = _amountsOut[_lastIndex];
    }

    function _swap(
        address[] memory _tokens,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        bool _reroute
    ) internal returns (uint256) {
        address _tokenIn = _tokens[0];
        uint256 _lastIndex = _tokens.length - 1;
        //if reroute is set to true generate route for tokenIn and tokenOut
        if (_reroute) {
            _tokens = _getRoute(_tokenIn, _tokens[_lastIndex]);
        }
        SafeERC20.forceApprove(IERC20(_tokenIn), address(ROUTER), _amountIn);
        uint256[] memory _amountsOut = ROUTER.swapExactTokensForTokens(
            _amountIn,
            _minAmountOut,
            _tokens,
            _receiver,
            block.timestamp
        );

        return _amountsOut[_lastIndex];
    }

    //The method `_getRoute` generates a route for a tokenSwap.
    //A route could be defined as an array such that route= [tokenIn,commonToken,tokenOut] ||[tokenIn,commonToken,commonToken,tokenOut]..
    //It is assumed that a pool exists between all common-tokens..
    function _getRoute(
        address _tokenIn,
        address _tokenOut
    ) internal view returns (address[] memory _route) {
        //create Max length for route
        _route = new address[](4);

        address[] memory _commonTokens = adapterState.commonTokens;
        _route[0] = _tokenIn;

        for (uint8 i; i < _commonTokens.length; i++) {
            /**
             * @notice  Loop to check if there exist a pool for a pair.
             * i.e if pool exist for 3% fee Tier
             */
            if (_poolExists(_tokenIn, _commonTokens[i], feeTier)) {
                _route[1] = _commonTokens[i];
                break;
            } else {
                continue;
            }
        }
        require(_route[1] != address(0));

        //checks if there exist a pool for route[1] and tokenOut
        ///first case we need to check if there exist a pool for tokenOut and _route[1]
        ///
        for (uint8 i = 0; i < _commonTokens.length; i++) {
            address _tokenOne = _commonTokens[i];

            if (_poolExists(_tokenOne, _tokenOut, feeTier)) {
                //if there exist a pool between _tokenOne and tokenOut and _tokenOne ==_route[1]
                //the route would be of a length==3
                //So route=[_tokenIn,common-token,_tokenOut]
                if (_route[1] == _tokenOne) {
                    _route[2] = _tokenOut;
                    break;
                }
                _route[2] = _tokenOne;
                _route[3] = _tokenOut;
                break;
            } else {
                continue;
            }
        }

        _validateRoute(_route);
        return _route;
    }

    function _validateRoute(address[] memory _route) internal pure {
        for (uint8 i; i < _route.length; ++i) {
            //Skip verification for 1==3
            //verifies that from 0-2 is not address(0)
            if (i == 3) {
                continue;
            }
            require(_route[i] != address(0));
        }
    }

    function addCommonTokens(address _token) external onlyAdapterOperator {
        require(_token != address(0));
        adapterState.commonTokens.push(_token);
        emit NewCommonToken(_token);
    }

    function removeCommonTokens(uint256 _index) external onlyAdapterOperator {
        address[] memory ctokens = adapterState.commonTokens;

        adapterState.commonTokens[_index] = ctokens[ctokens.length - 1];
        //Swap the index with the lastIndex..
        adapterState.commonTokens.pop();
    }

    function _poolExists(
        address _tokenIn,
        address _tokenOut,
        uint256 _fee
    ) internal view returns (bool exists) {
        //experimenting with __ as place holders funny though..
        address __ = FACTORY.getPool(_tokenIn, _tokenOut, uint24(_fee));
        exists = __ != address(0) ? true : false;
    }
}
