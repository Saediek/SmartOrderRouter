//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;

/**
 * A Swap is like a bet speculating that the Router wouldn't beat the minAmountOut price
 * When the Swap is settled if it doesn't beat the minAmountOut Tx's revert else the router gets
 * to keep a percentage of the difference between the (amountOut-MinAmountOut)..
 * So to put it simply minAmount serves as a threshold for a swap and then the initiator and the router gets to keep
 * the difference if positive..
 */
interface ISmartOrderRouter {
    error unauthorisedOperation(address);
    error InvalidAdapter(AdapterInfo);
    struct State {
        address operator;
        bool isPause;
        AdapterInfo[] adapters;
        uint16 feeSplit;
        address[] routerOwnedTokens;
    }
    struct SwapResult {
        address _receiver;
        address _tokenOut;
        address _route;
        uint256 _routerSplit;
        uint256 _amountOut;
    }
    event SwapCompleted(SwapResult);
    struct AdapterInfo {
        address _adapterAddress;
        uint256 adapterActiveLiquidity;
        uint64 _adapterFee;
        string name;
    }

    function Swap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        address[] memory _tokenRoute,
        bool _reroute
    ) external payable returns (uint256);

    function computeAmountOut(
        address[] memory _token,
        uint256 _amountIn,
        bool _reroute
    ) external view returns (uint256);

    //PERMISSIONED FUNCTIONALITIES//
    function addAdapter(
        AdapterInfo memory _adapterInfo
    ) external returns (uint);

    function removeAdapter(uint256 _index) external;

    //Pause or unpause the router
    function pauseRouter(bool _state) external;

    function setSplitInBps(uint16 _routerSplit) external;

    function getAdapters() external view returns (AdapterInfo[] memory);

    function getOperator() external view returns (address);

    function getRouterSplit() external view returns (uint16);

    function claimWinnings(
        address[] memory _tokens,
        address _receiver
    ) external;
}
