//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;

/**
 * \
 * @author <Saediek ||saediek@proton.me>
 * @notice  A Swap is like a bet speculating that the Router wouldn't beat the minAmountOut price
 * When the Swap is settled if it doesn't beat the minAmountOut Tx's revert else the router gets
 * to keep a percentage of the difference between the (amountOut-MinAmountOut)..
 * So to put it simply minAmount serves as a threshold for a swap and then the initiator and the router gets to keep
 * the difference if positive..
 */
interface ISmartOrderRouter {
    error unauthorisedOperation(address);
    error InvalidAdapter(AdapterInfo);

    struct State {
        //1st Slot
        address operator;
        //1st Slot
        bool isPause;
        //2nd Slot
        AdapterInfo[] adapters;
        uint16 feeSplit;
        address[] routerOwnedTokens;
        mapping(address => bool) isRegistered;
    }

    struct SwapResult {
        //Occupies Five  Slots..
        address _receiver;
        address _tokenOut;
        address[] _route;
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

    /**
     * TokenIn is the address or IERC20 Token a user is willing to trade for another token. This is always stored at the *0th index of the array _tokenRoute
     * TokenOut is the address or IERC20 Token a user wants to receive.This variable is stored in the *lastIndex of _tokenRouter i.e lastIndex=_tokenRoute.length-1;
     * @param _amountIn Amount of an TokenIn the caller is willing to swap
     * for another TokenOut
     * @param _minAmountOut Minimum amount  of TokenOut the user is willing to accept from a swap
     * to conclude tokens exchange.
     * @param _receiver  Address of the receiver of the resulting amount of TokenOut..
     * @param _tokenRoute An array of IERC20 Token which the trade must follow sequentially
     * till tokenOut
     * @param _reroute A boolean flag indicating if a reroute is needed..
     */
    function Swap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        address[] memory _tokenRoute,
        bool _reroute
    ) external payable returns (uint256);

    function computeAmountOut(address[] memory _token, uint256 _amountIn, bool _reroute)
        external
        view
        returns (uint256);

    //PERMISSIONED FUNCTIONALITIES//
    function addAdapter(AdapterInfo memory _adapterInfo) external returns (uint256);

    function removeAdapter(uint256 _index) external;

    //Pause or unpause the router
    function pauseRouter(bool _state) external;

    function setSplitInBps(uint16 _routerSplit) external;

    function getAdapters() external view returns (AdapterInfo[] memory);

    function getOperator() external view returns (address);

    function getRouterSplit() external view returns (uint16);

    function claimWinnings(address[] memory _tokens, address _receiver) external;
}
