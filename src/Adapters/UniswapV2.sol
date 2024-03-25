//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;

import "../Interfaces/IAdapter.sol";
import "../Interfaces/IUniswapv2.sol";
import {IERC20, SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

/**
 * @title UNISWAP-V2-ADAPTER
 * @author <Saediek@proton.me>
 * @notice
 */
contract Uniswap2Adapter is IAdapter {
    using SafeERC20 for uint256;

    string public constant Name = "UNISWAP-V2-ADAPTER";
    AdapterState adapterState;

    IUniswapV2 public immutable ROUTER;
    modifier onlyAdapterOperator() {
        require(adapterState.adapterOperator == msg.sender);
        _;
    }

    constructor(address _router) {
        ROUTER = IUniswapV2(_router);
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

    function _getRoute(
        address _tokenIn,
        address _tokenOut
    ) internal view returns (address[] memory) {}

    function addCommonTokens(address _token) external onlyAdapterOperator {}

    function addFeeTiers(uint256 _feeTier) external onlyAdapterOperator {
        require(_feeTier != 0);
        adapterState.feeTiers.push(_feeTier);
        emit NewFeeTier(_feeTier);
    }

    //A fee Tier is to be removed without breaking the order..
    function removeFeeTier(uint8 _feeTierIndex) external onlyAdapterOperator {}
}
