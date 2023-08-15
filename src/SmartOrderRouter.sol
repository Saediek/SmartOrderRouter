//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.0;
import "src/Interfaces/IERC20.sol";
import "src/Libraries/SafeERC20.sol";

import "openzeppelin/access/Ownable.sol";
import "src/Libraries/AddressUtils.sol";
import "src/Interfaces/IWETH.sol";

/**Abstract:Smart order router is an algorithm used to find the best available price,liquidity & conditions for a trade
 *Find best price across multiple Dexes in a network of Dexes,execute trade on the  most efficient dex
 *DEXES:UNISWAPV2,UNISWAPV3,CURVE-FINANCE,DYDX,BALANCER,SUSHI,LOOPRING,BANCOR,FRXSWAP ,PANCAKE...
 *Owner could add dexes
 */

contract SmartOrderRouter is Ownable {
    //======LIBRARIES=======//
    //======================//

    using AddressUtils for address[];
    using SafeERC20 for IERC20;
    //====VARIABLES====//
    //=================//
    address[] Modules;
    struct Module_detail {
        uint256 current_Price;
        uint256 _index;
    }
    address immutable weth;
    //Modules support for multiSwap
    mapping(address => bool) SupportMultiSwap;
    //=======EVENTS=========//
    //======================//
    event SingleSwap(
        address _tokenIn,
        address _tokenOut,
        uint256 bestPrice,
        address _caller
    );
    event MultiSwap(address[] _route, uint256 bestPrice, address _caller);
    event AddedModule(address[] _module);
    event RemoveModule(address _module);

    constructor(address[] memory _modules, address _weth) {
        Modules = _modules;
        weth = _weth;
    }

    //getBestPrice for a trade
    //getRouter for if pools exists if they exists get their prices and compare their pools
    // The best prices:would be returned
    //========VIEW-METHODS========//
    //============================//
    function getBestPricesForSingleSwap(
        address _token1,
        address _token2,
        uint256 _amountIn
    ) public view returns (uint256 _price, address pool) {
        Module_detail memory cached_details;

        for (uint256 i; i < Modules.length; ) {
            (bool sucess, bytes memory data) = Modules[i].staticcall(
                abi.encodeWithSignature(
                    "getPrice(address,address,uint256)",
                    _token1,
                    _token2,
                    _amountIn
                )
            );
            if (!sucess) {
                continue;
            }
            uint256 _amount = abi.decode(data, (uint256));

            if (_amount > cached_details.current_Price) {
                cached_details.current_Price = _amount;
                cached_details._index = i;
            }
            unchecked {
                i++;
            }
        }
        _price = cached_details.current_Price;
        pool = Modules[cached_details._index];
    }

    function getBestPricesForMultiSwaps(
        uint256 _amountIn,
        address[] memory _path
    ) internal view returns (uint256 _amountOut, address _module) {}

    /**
     *
     *
     */
    //========WRITE-METHODS=======//
    //============================//
    function SwapTokensSingleTokensForTokens(
        uint256 _amountIn,
        address tokenIn,
        address tokenOut,
        uint256 _minAmountOut
    ) public returns (uint256 _amountOut) {
        (uint256 _price, address _module) = getBestPricesForSingleSwap(
            tokenIn,
            tokenOut,
            _amountIn
        );
        if (_price < _minAmountOut) {
            revert("AmountOut less than Min");
        }
        IERC20(tokenIn).safeTransfer(_module, _amountIn);

        bytes memory payload = abi.encodeWithSignature(
            "SingleSwap(address,address,uint256,uint256)",
            tokenIn,
            tokenOut,
            _amountIn,
            _minAmountOut
        );
        (bool sucess, bytes memory returndata) = _module.call(payload);
        if (!sucess) {
            revert("SingleSwap Failed");
        }
        _amountOut = abi.decode(returndata, (uint256));
        emit SingleSwap(tokenIn, tokenOut, _amountOut, msg.sender);
    }

    /**
     *Abstract: Due to discrepancies among  Dexes arbitrage opportunities exists among dexes
     * This is a MultiSwap method among Interdexes to exploit price differences ||dicrepancies on dexes
     *
     *@param amount The amount of _path[0] token or an amount of the genesis path token a user wants is willing to trade
     */

    function SwapTokenForTokensMultiDex(
        uint256 amount,
        address[] memory _path,
        uint256[] memory AmountMin
    ) external returns (uint256 _amountOut) {
        uint256 tempAmt;

        for (uint8 i; i < _path.length; ) {
            if (i == 0) {
                tempAmt = SwapTokensSingleTokensForTokens(
                    amount,
                    _path[i],
                    _path[++i],
                    AmountMin[i]
                );
            } else {
                tempAmt = SwapTokensSingleTokensForTokens(
                    tempAmt,
                    _path[i],
                    _path[++i],
                    AmountMin[i]
                );
            }

            unchecked {
                ++i;
            }
        }
        _amountOut = tempAmt;
        emit MultiSwap(_path, _amountOut, msg.sender);
    }

    /**
     *
     *
     *
     */

    function SwapTokenForTokensSingleDex(
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minOut
    ) external returns (uint256 _amountOut) {
        (uint256 price, address _module) = getBestPricesForMultiSwaps(
            _amountIn,
            _path
        );
        if (price < _minOut) {
            revert("price<Min-amount");
        }
        bytes memory data = abi.encodeWithSignature(
            "MultiSwap(uint256,address[],uint256)",
            _amountIn,
            _path,
            _minOut
        );

        IERC20(_path[0]).safeTransfer(_module, _amountIn);
        (bool sucess, bytes memory results) = _module.call(data);
        if (!sucess) {
            revert("MultiSwap Failed");
        }
        _amountOut = abi.decode(results, (uint256));

        IERC20(_path[_path.length - 1]).safeTransfer(msg.sender, _amountOut);
        emit MultiSwap(_path, _amountOut, msg.sender);
    }

    function SwapTokenForETH(
        address _tokenIn,
        uint256 _amountIn,
        uint256 _minAmount
    ) external returns (uint256 _amountOut) {
        (uint256 _price, address _module) = getBestPricesForSingleSwap(
            _tokenIn,
            weth,
            _amountIn
        );
        if (_price < _minAmount) {
            revert("Price< min-amount");
        }
        bytes memory payload = abi.encodeWithSignature(
            "SingleSwap(address,address,uint256,uint256)",
            _tokenIn,
            weth,
            _amountIn,
            _minAmount
        );
        IERC20(_tokenIn).safeTransfer(_module, _amountIn);

        (bool sucess, bytes memory returndata) = _module.call(payload);
        if (!sucess) {
            revert("Swap Failed");
        }
        _amountOut = abi.decode(returndata, (uint256));
        IWETH(weth).withdraw(_amountOut);
        (bool _sucess, ) = msg.sender.call{value: _amountOut}("");
        require(_sucess, "Low-level transfer ETH failed");
        emit SingleSwap(_tokenIn, weth, _price, msg.sender);
    }

    function SwapETHForTokens(
        address[] memory _path,
        uint256 _minAmount
    ) external payable returns (uint256 _amountOut) {
        (uint256 price, address _module) = getBestPricesForMultiSwaps(
            msg.value,
            _path
        );
        if (price < _minAmount) {
            revert("price<Min-amount");
        }
        if (_path[0] != weth) {
            revert("_path invalid path");
        }
        IWETH(weth).deposit{value: msg.value};
        bytes memory payload = abi.encodeWithSignature(
            "MultiSwap(uint256,address[],uint256)",
            msg.value,
            _path,
            _minAmount
        );

        IERC20(weth).safeTransfer(_module, msg.value);
        (bool sucess, bytes memory returndata) = _module.call(payload);
        if (!sucess) {
            revert("MultiSwap failed");
        }
        _amountOut = abi.decode(returndata, (uint256));
        IERC20(_path[_path.length - 1]).safeTransfer(msg.sender, _amountOut);
        emit MultiSwap(_path, price, msg.sender);
    }

    function SwapETHForToken(
        address _tokenOut,
        uint256 _minAmount
    ) external payable returns (uint256 _amountOut) {
        (uint256 _price, address _module) = getBestPricesForSingleSwap(
            weth,
            _tokenOut,
            msg.value
        );
        if (_price < _minAmount) {
            revert("price<Min-amount");
        }
        IWETH(weth).deposit{value: msg.value};

        bytes memory payload = abi.encodeWithSignature(
            "SingleSwap(uint256,address,address,uint256)",
            msg.value,
            weth,
            _tokenOut,
            _minAmount
        );
        IERC20(weth).safeTransfer(_module, msg.value);

        (bool sucess, bytes memory returndata) = _module.call(payload);
        if (!sucess) {
            revert("Swap failed");
        }
        _amountOut = abi.decode(returndata, (uint256));
        IERC20(_tokenOut).safeTransfer(msg.sender, _amountOut);
        emit SingleSwap(weth, _tokenOut, _price, msg.sender);
    }

    function addModules(address[] memory _newModule) public onlyOwner {
        address[] memory _existing = Modules;
        _existing = _existing.extend(_newModule);
        _existing.hasDuplicate();
        Modules = _existing;
        emit AddedModule(_newModule);
    }

    function removeModule(address _module, uint256 _index) public onlyOwner {
        if (_module == address(0)) {
            Modules.removeStorage(Modules[_index]);
        } else {
            Modules.removeStorage(_module);
        }
        emit RemoveModule(Modules[_index]);
    }

    receive() external payable {
        (, bool IsIn) = Modules.indexOf(msg.sender);
        if (msg.sender != weth || IsIn) {
            revert("unknown caller");
        }
    }
}
