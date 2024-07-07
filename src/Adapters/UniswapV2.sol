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
    using SafeERC20 for address;
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

    constructor(address _router, address _factory, address _operator) {
        ROUTER = IUniswapV2(_router);
        FACTORY = IUniswapV2Factory(_factory);
        adapterState.adapterOperator = _operator;
    }

    function initialise(
        address _newOperator,
        address _sor
    ) external onlyAdapterOperator {
        adapterState.adapterOperator = _newOperator;
        adapterState.SmartOrderRouter = _sor;
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

        _amountOut = _amountsOut[_amountsOut.length - 1];
    }

    function _swap(
        address[] memory _tokens,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        bool _reroute
    ) internal returns (uint256) {
        address _tokenIn = _tokens[0];
        address _tokenOut = _tokens[_tokens.length - 1];

        //if reroute is set to true generate route for tokenIn and tokenOut
        if (_reroute) {
            _tokens = _getRoute(_tokenIn, _tokenOut);
        }
        SafeERC20.forceApprove(IERC20(_tokenIn), address(ROUTER), _amountIn);
        uint256 _balanceTokenOut = IERC20(_tokenOut).balanceOf(_receiver);
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amountIn,
            _minAmountOut,
            _tokens,
            _receiver,
            block.timestamp
        );
        return IERC20(_tokenOut).balanceOf(_receiver) - _balanceTokenOut;
    }

    //The method `_getRoute` generates a route for a tokenSwap.
    //A route could be defined as an array such that route= [tokenIn,commonToken,tokenOut] ||[tokenIn,commonToken,commonToken,tokenOut]..
    //It is assumed that a pool exists between all common-tokens..
    function _getRoute(
        address _tokenIn,
        address _tokenOut
    ) internal view returns (address[] memory _route) {
        address _token0Pair;
        address _token1Pair;
        address[] memory _commonTokens = adapterState.commonTokens;
        for (uint8 i; i < _commonTokens.length; i++) {
            address _cToken = _commonTokens[i];
            if (_token0Pair != address(0) && _token1Pair != address(0)) {
                break;
            }
            if (_poolExists(_tokenIn, _cToken)) {
                _token0Pair = _cToken;
            }
            if (_poolExists(_tokenOut, _cToken)) {
                _token1Pair = _cToken;
            }
        }
        if (_token0Pair != _token1Pair) {
            _route = new address[](4);
            _route[0] = _tokenIn;
            _route[1] = _token0Pair;
            _route[2] = _token1Pair;
            _route[3] = _tokenOut;
        } else {
            _route = new address[](3);
            _route[0] = _tokenIn;
            _route[1] = _token0Pair;
            _route[2] = _tokenOut;
        }

        _validateRoute(_route);
        return _route;
    }

    function _validateRoute(address[] memory _route) internal pure {
        for (uint8 i; i < _route.length; ++i) {
            //Skip verification for 1==3
            //verifies that from 0-2 is not address(0)
            require(_route[i] != address(0), "PNF");
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

    function getCommonTokens()
        external
        view
        returns (address[] memory _tokens)
    {
        _tokens = adapterState.commonTokens;
    }

    function _poolExists(
        address _tokenIn,
        address _tokenOut
    ) internal view returns (bool exists) {
        //experimenting with __ as place holders funny though..
        address __ = FACTORY.getPair(_tokenIn, _tokenOut);
        exists = __ != address(0) ? true : false;
    }
}
