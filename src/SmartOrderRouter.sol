//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.0;
import "src/Interfaces/IERC20.sol";
import "src/Libraries/SafeERC20.sol";

import "openzeppelin/access/Ownable.sol";
import "src/Libraries/AddressUtils.sol";
import "src/Interfaces/IWETH.sol";
import "src/Interfaces/IUniswapV3.sol";

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
    module[] public Modules;
    struct Module_detail {
        uint240 current_Price;
        uint16 _index;
    }
    struct module {
        address adapter;
        string name;
        string description;
        uint256 _fees; // fees percentage in 1e18
        bool supportsFlashloans;
    }
    address immutable weth;
    address flashloanModule;

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
    event deletedModule(uint8);
    event MultiSwap(address[] _route, uint256 bestPrice, address _caller);
    event AddedModule(string, address, uint8 index, bool);
    event RemoveModule(address _module);
    modifier OnlyFlashLoanModule() {
        if (msg.sender != flashloanModule) {
            revert("Unauthorized caller");
        }
        _;
    }

    constructor(address _weth) {
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
            (bool sucess, bytes memory data) = Modules[i].adapter.staticcall(
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
                cached_details.current_Price = uint240(_amount);
                cached_details._index = uint16(i);
            }
            unchecked {
                i++;
            }
        }
        _price = cached_details.current_Price;
        pool = Modules[cached_details._index].adapter;
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
    /**
     *Add a single module to the list of modules
     * @param _adapter :Address of the new module
     * @param _name : Name of module
     * @param _description :Brief description of the module
     *@param _fees : Fee of the module
     *@param _supportsFlashloans does the Module supports flashloans
     */
    function addModule(
        address _adapter,
        string memory _name,
        string memory _description,
        uint256 _fees,
        bool _supportsFlashloans
    ) external returns (uint8 _index) {
        require(_adapter != address(0));
        module memory _cached = module(
            _adapter,
            _name,
            _description,
            _fees,
            _supportsFlashloans
        );
        Modules.push(_cached);
        _index = uint8(Modules.length - 1);
        emit AddedModule(_name, _adapter, _index, _supportsFlashloans);
    }

    /**
     *Remove an existing module
     @param _index the index of the module would throw if out of bound
     */
    function removeModule(uint8 _index) external {
        delete Modules[_index];
        emit deletedModule(_index);
    }

    /*
    *Trades amountIn of tokenIn ->> for an amount of tokenOut
    @param tokenIn: Address  of the base Token
    @param tokenOut:Address of Quote Token
    @param _amountIn: Amount of tokenIn the user is willing trade
    @param _minAmountOut:Minimum amount of _tokenOut a user is willing to accept from the trade
    @return _amountOut The amount of the tokenOut received from the trade
     */

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
     *Abstract: Due to discrepancies among  Dexes arbitrage opportunities continue to exists among dexes
     *Discrepancies are a result of dexes using different pricing techniques
     * This is a MultiSwap method among Interdexes to exploit price differences ||dicrepancies on dexes
     *@param _path :Route or intemediary tokens for a trade
     *@param AmountMin :Minimum amount of _path[n] that a user is willing to accept {where n=length of _path -1 || last route}
     
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
        IERC20(_path[_path.length - 1]).safeTransfer(msg.sender, tempAmt);
        _amountOut = tempAmt;

        emit MultiSwap(_path, _amountOut, msg.sender);
    }

    /**
     *Swap tokens through a given route within a dex
     *@param _path :Route or intemediary tokens for a trade
     *@param _amountIn :Amount of genesis _path || _path[0] a user wants to trade;
     *@param _minOut :Minimum amount of _path[n] that a user is willing to accept {where n=length of _path -1 || last route}
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

    /**
     *Swap ETH->_path[0]->_path[n] where n is the number of intermediary tokens and _path[n] is the token being received by
     *the user
     *@param _path: An array of tokens || route of the trade
     *@param _minAmount :Minimum amount of _path[n] a trader is willing to receive {where n is the number of intermediary tokens}
     *@param _amountOut :Actual amount received from the trade {_amountOut>=_minAmount}
     */
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

    /**
     *Swap ETH for IERC20 token
     *@param _tokenOut :Address of the token users wants to receive for their ETH
     *@param _minAmount : Minimum amount of tokenOut a trader is willing to accept from the trade(Slippage control)
     *@param _amountOut :Actual amount of _tokenOut a trader receives where _amount0ut>=_minAmount
     */

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

    /**
     *Execute an arbitrage on a single Module
     *An arbitrage on a single Module is more like a list of methods aiming at a profit
     *_path[0] && _path[_path.length-1] must be same token.
     */
    function Arbitrage(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256 _index,
        bytes memory _payload
    ) external {
        if (!Modules[_index].supportsFlashloans) {
            revert("Modules doesn't support flashloan");
        }
        bytes memory payload = abi.encodeWithSignature(
            "flashloan(address[],uint256[],bytes,address)",
            _tokens,
            _amounts,
            _payload,
            msg.sender
        );
        (bool sucess, ) = Modules[_index].adapter.call(payload);
        if (!sucess) {
            revert("Flasloan failed");
        }
    }

    receive() external payable {
        if (_msgSender() != weth) {
            revert("Unauthorized caller");
        }
    }
}
