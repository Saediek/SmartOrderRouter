//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;

import "../Interfaces/IAdapter.sol";
import "../Interfaces/IUniswapv2.sol";
import "../Interfaces/IUniswapV2Factory.sol";
import {IERC20, SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

/**
 * @title UNISWAP-V2-ADAPTER
 * @author <Saediek ||Saediek@proton.me>
 */
contract Uniswap2Adapter is IAdapter {
    using SafeERC20 for uint256;

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
        if (_reroute) {
            _tokens = _getRoute(_tokens[0], _tokens[_tokens.length - 1]);
        }
        uint256[] memory _amountsOut = ROUTER.getAmountsOut(_amountIn, _tokens);
        uint256 _cachedLength = _amountsOut.length - 1;
        _amountOut = _amountsOut[_cachedLength];
    }

    function _swap(
        address[] memory _tokens,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        bool _reroute
    ) internal returns (uint256) {
        address _tokenIn = _tokens[0];
        if (_reroute) {
            _tokens = _getRoute(_tokens[0], _tokens[_tokens.length - 1]);
        }
        SafeERC20.forceApprove(IERC20(_tokenIn), address(ROUTER), _amountIn);
        uint256[] memory _amountsOut = ROUTER.swapExactTokensForTokens(
            _amountIn,
            _minAmountOut,
            _tokens,
            _receiver,
            block.timestamp
        );
        uint256 _cachedLength = _amountsOut.length - 1;
        return _amountsOut[_cachedLength];
    }

    //A route could be defined as an array such that route= [tokenIn,commonToken,tokenOut] ||[tokenIn,commonToken,commonToken,tokenOut]..
    function _getRoute(
        address _tokenIn,
        address _tokenOut
    ) internal view returns (address[] memory) {
        uint256[] memory _feeTiers = adapterState.feeTiers;
        address[] memory _commonTokens = adapterState.commonTokens;
    }

    function addCommonTokens(address _token) external onlyAdapterOperator {
        require(_token != address(0));
        adapterState.commonTokens.push(_token);
        emit NewCommonToken(_token);
    }

    function addFeeTiers(uint256 _feeTier) external onlyAdapterOperator {
        require(_feeTier != 0);
        adapterState.feeTiers.push(_feeTier);
        emit NewFeeTier(_feeTier);
    }

    function _poolExists(
        address _tokenIn,
        address _tokenOut,
        uint24 _fee
    ) internal view returns (bool exists) {
        //experimenting with __ as place holders funny though..
        address __ = FACTORY.getPool(_tokenIn, _tokenOut, _fee);
        exists = __ != address(0) ? true : false;
    }

    //A fee Tier is to be removed without breaking the order..
    //or sequence of the Tier List which acts more like a priority Queue
    //First Tier gets examined if the pool doesn't exists then go to next tier..
    //Swap index of next index and then pop item..
    function removeFeeTier(uint8 _feeTierIndex) external onlyAdapterOperator {
        uint256[] memory _feeTiers = adapterState.feeTiers;
        uint256 val = _feeTiers[_feeTierIndex];
        for (uint8 i = _feeTierIndex; i < _feeTiers.length - 1; i++) {
            uint256 _currentItem = _feeTiers[i];
            uint256 _nxtItem = _feeTiers[i + 1];
            _feeTiers[i] = _nxtItem;
            _feeTiers[i + 1] = _currentItem;
        }
        adapterState.feeTiers = _feeTiers;
        adapterState.feeTiers.pop();
        emit removedFeeTier(val);
    }
}
