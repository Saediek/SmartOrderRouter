//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;

import "src/Interfaces/ISmartOrderRouter.sol";
import "src/Interfaces/IAdapter.sol";
import {SafeERC20, IERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "src/Interfaces/IWETH.sol";

contract SmartOrderRouter is ISmartOrderRouter {
    using SafeERC20 for IERC20;
    ///restrict access control of some functionalities to a specific address.

    modifier onlyOperator() {
        if (msg.sender != routerState.operator) {
            revert unauthorisedOperation(msg.sender);
        }
        _;
    }
    /// Modifier to ensure the router is not in the current state it's about to enter assymetry to the 'notPaused' modifier
    modifier pause(bool _state) {
        require(routerState.isPause != _state);
        _;
    }
    //use to pause and un-pause the router in different state

    modifier notPaused() {
        require(!routerState.isPause);
        _;
    }

    State internal routerState;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    //represents the Maximum  shares in  bps that the router is
    //entitled toi.e  5% of the difference between amountOut-minAmount.
    uint256 constant MAX_SPLIT = 500;

    uint256 constant MAX_BPS = 10000;

    constructor(address _operator, uint16 _routerShareBps) {
        _init(_operator, _routerShareBps);
    }

    function _init(address _operator, uint16 _routerShareBps) internal {
        if (_operator == address(0)) {
            _operator = msg.sender;
        }

        routerState.operator = _operator;
        routerState.feeSplit = _routerShareBps;
        routerState.isPause = false;
    }

    function Swap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        address[] memory _tokenRoute,
        bool _reroute
    ) external payable notPaused returns (uint256 _amountOut) {
        //if ether is being sent then token-In must be weth..
        if (msg.value > 0) {
            require(_tokenRoute[0] == WETH);
            _wrap();
            _amountIn = msg.value;
        }
        //Get the best rate from all adapters and return the best rate and the index of the adapter
        //offering the best rate..
        (uint256 _index, uint256 _expectedAmt) = _fetchBestRate(
            _tokenRoute,
            _amountIn,
            _reroute
        );
        if (_expectedAmt < _minAmountOut) {
            revert();
        }
        AdapterInfo memory _adapter = routerState.adapters[_index];
        _handleTransfer(_tokenRoute[0], _adapter._adapterAddress, _amountIn);

        _expectedAmt = IAdapter(_adapter._adapterAddress).Swap(
            _tokenRoute,
            _amountIn,
            _minAmountOut,
            _receiver,
            _reroute
        );
        //cache the dstToken in memory
        address _dstToken = _tokenRoute[_tokenRoute.length - 1];
        uint256 _routerShare = _split(_expectedAmt - _minAmountOut, _dstToken);
        _amountOut = _expectedAmt - _routerShare;
        IERC20(_dstToken).safeTransfer(_receiver, _amountOut);
        SwapResult memory res = SwapResult({
            _receiver: _receiver,
            _tokenOut: _dstToken,
            _route: _tokenRoute,
            _routerSplit: _routerShare,
            _amountOut: _amountOut
        });
        emit SwapCompleted(res);
    }

    function computeAmountOut(
        address[] memory _token,
        uint256 _amountIn,
        bool _reroute
    ) external view returns (uint256 _bestRate) {
        (, _bestRate) = _fetchBestRate(_token, _amountIn, _reroute);
    }

    function addAdapter(
        AdapterInfo memory _adapterInfo
    ) external onlyOperator returns (uint256 _index) {
        _validateInfo(_adapterInfo);

        _index = routerState.adapters.length;

        routerState.adapters.push(_adapterInfo);
    }

    function removeAdapter(uint256 _index) external onlyOperator {
        AdapterInfo[] storage _adapters = routerState.adapters;
        //Get last Adapter and Swap for _index and then pop
        AdapterInfo memory _lastAdapter = _adapters[_adapters.length - 1];
        _adapters[_index] = _lastAdapter;
        _adapters.pop();
    }

    //Pauses or UnPauses Swap functionalities in the router
    //Actions could be carried out  by only the operator which is enforced with
    //an `onlyOperator` modifier..
    function pauseRouter(bool _state) external onlyOperator pause(_state) {
        routerState.isPause = _state;
    }

    //Operator only method to modify the router split which is
    //Limited to `MAX_SPLIT` variable or capped to 5% shares..
    function setSplitInBps(uint16 _routerSplit) external onlyOperator {
        require(_routerSplit <= MAX_SPLIT);
        routerState.feeSplit = _routerSplit;
    }

    function getAdapters() external view returns (AdapterInfo[] memory) {
        //returns all active adapters..
        return routerState.adapters;
    }

    /**
     * Best Price is gotten by looping through the  adapters and fetching the current rate they offer for
     *  the Swap, the adapter with the highest rate wins the swap..
     */
    function _fetchBestRate(
        address[] memory _tokens,
        uint256 _amountIn,
        bool _reroute
    ) internal view returns (uint8 _indexOfAdapter, uint256 _amountOut) {
        AdapterInfo[] memory _adapters = routerState.adapters;
        for (uint8 i; i < _adapters.length; i++) {
            try
                IAdapter(_adapters[i]._adapterAddress).computeAmountOut(
                    _tokens,
                    _amountIn,
                    _reroute
                )
            returns (uint256 amountOut) {} catch {}
        }
    }

    function _wrap() internal {
        IWETH(WETH).deposit{value: msg.value}();
    }

    function _handleTransfer(
        address _token,
        address _adapter,
        uint256 _amount
    ) internal {
        IERC20(_token).safeTransferFrom(msg.sender, _adapter, _amount);
    }

    function _split(
        uint256 _diff,
        address _token
    ) internal returns (uint256 _routerShare) {
        uint256 _routerSplit = routerState.feeSplit;
        if (_routerSplit != 0) {
            _routerShare = (_routerSplit * _diff) / MAX_BPS;
            if (!isRegisteredToken(_token)) {
                routerState.routerOwnedTokens.push(_token);
                routerState.isRegistered[_token] = true;
            }
        }
    }

    //@todo Implement a better lookup solution which takes a simpler approach that
    function isRegisteredToken(address _token) internal view returns (bool) {
        require(_token != address(0));
        return routerState.isRegistered[_token];
    }

    function getOperator() external view returns (address) {
        return routerState.operator;
    }

    function getRouterSplit() external view returns (uint16) {
        return routerState.feeSplit;
    }

    function claimWinnings(
        address[] memory _tokens,
        address _receiver
    ) external onlyOperator {
        require(_receiver != address(0));
        for (uint8 i; i < _tokens.length; i++) {
            uint256 value = IERC20(_tokens[i]).balanceOf(address(this));

            IERC20(_tokens[i]).safeTransfer(_receiver, value);
        }
    }

    function _validateInfo(AdapterInfo memory _info) internal pure {
        if (_info._adapterAddress == address(0) || _info._adapterFee == 0) {
            revert InvalidAdapter(_info);
        }
    }
}
