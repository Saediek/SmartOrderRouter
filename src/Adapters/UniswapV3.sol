/**
 * SPDX-License-Identifier:UNLICENSED
 * @author Saediek ||<Saediek@proton.me>
 */
pragma solidity ^0.8;

import "../Interfaces/IAdapter.sol";
import {IERC20, SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IUniswapFactory, IUniswapV3} from "../Interfaces/IUniswapV3.sol";
using SafeERC20 for IERC20;

abstract contract UniswapV3Adapter is IAdapter {
    string public constant Name = "UNISWAP-V3-ADAPTER";
    AdapterState private adapterState;
    IUniswapFactory private immutable FACTORY;

    IUniswapV3 private immutable ROUTER;

    modifier onlyOperator() {
        require(msg.sender == adapterState.adapterOperator);
        _;
    }

    constructor() {}

    function Swap(
        address[] memory _tokens,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        bool _reroute,
        bytes memory _data
    ) external payable returns (uint256) {
        return
            _swap(
                _tokens,
                _amountIn,
                _minAmountOut,
                _data,
                _receiver,
                _reroute
            );
    }

    function computeAmountOut(
        address[] memory _tokens,
        uint256 _amountIn
    ) external view returns (uint256 _amountOut) {}

    function setFeeTiers(uint24[] memory _feeTiers) external onlyOperator {
        adapterState.feeTiers = _feeTiers;
    }

    function _swap(
        address[] memory _tokens,
        uint256 _amountIn,
        uint256 _minAmountOut,
        bytes memory _data,
        address _receiver,
        bool _reroute
    ) internal returns (uint256) {
        uint24[] memory _fees;
        if (_reroute) {
            (_tokens, _fees) = _generateRoute(
                _tokens[0],
                _tokens[_tokens.length - 1]
            );

            ///
        }

        IERC20(_tokens[0]).forceApprove(address(ROUTER), _amountIn);
        IUniswapV3.ExactInputParams memory _params;
        if (_reroute) {
            bytes memory encodedPath = encodePath(_tokens, _fees);
            _params = IUniswapV3.ExactInputParams(
                encodedPath,
                _receiver,
                block.timestamp,
                _amountIn,
                _minAmountOut
            );
        } else {
            _params = IUniswapV3.ExactInputParams(
                _data,
                _receiver,
                block.timestamp,
                _amountIn,
                _minAmountOut
            );
        }
        return ROUTER.exactInput(_params);
    }

    function encodePath(
        address[] memory _tokens,
        uint24[] memory _fees
    ) internal pure returns (bytes memory _path) {}

    function _generateRoute(
        address _tokenIn,
        address _tokenOut
    ) internal view returns (address[] memory _route, uint24[] memory _fees) {
        uint256[] memory _feeTiers = adapterState.feeTiers;
        address[] memory cTokens = adapterState.commonTokens;
        uint24 _fee0;
        uint24 _fee1;
        address token0;
        address token1;
        ///Time-Complexity=x^2 +y..
        //where x=time to loop through common-Tokens..
        {
            //Add scope to drop params from stack..
            for (uint8 i; i < cTokens.length; i++) {
                address _ctoken = cTokens[i];
                if (token0 != address(0) && token1 != address(0)) {
                    break;
                }
                for (uint8 j; j < _feeTiers.length; j++) {
                    uint24 _fee = uint24(_feeTiers[j]);
                    if (poolExists(_tokenIn, _ctoken, _fee)) {
                        token0 = _ctoken;
                        _fee0 = _fee;
                        break;
                    }
                }
                for (uint8 x; x < _feeTiers.length; x++) {
                    uint24 _fee = uint24(_feeTiers[x]);
                    if (poolExists(_tokenOut, _ctoken, _fee)) {
                        token1 = _ctoken;
                        _fee1 = _fee;
                        break;
                    }
                }
            }
        }
        if (token0 == token1 && _fee0 == _fee1) {
            _route = new address[](3);
            _fees = new uint24[](2);
            _fees[0] = _fee0;
            _fees[1] = _fee1;
        } else {
            _route = new address[](4);
            _route[0] = _tokenIn;
            _route[1] = token0;
            _route[2] = token1;
            _route[3] = _tokenOut;
            _fees = new uint24[](3);
            _fees[0] = _fee0;
            _fees[1] = 3000;
            _fees[2] = _fee1;
        }

        _validateRoute(_route);
    }

    function poolExists(
        address _token0,
        address _token1,
        uint24 _fee
    ) internal view returns (bool) {
        (address token0, address token1) = _token0 < _token1
            ? (_token0, _token1)
            : (_token1, _token0);
        address _pool = FACTORY.getPool(token0, token1, _fee);
        return _pool != address(0) ? true : false;
    }

    function _validateRoute(address[] memory _route) internal pure {
        for (uint8 i; i < _route.length; i++) {
            if (_route[i] == address(0)) {
                revert("Bad Route");
            }
        }
    }
}
