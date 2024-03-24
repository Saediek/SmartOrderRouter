/**
 * SPDX-License-Identifier:UNLICENSED
 * @author :Saediek || <Saediek@proton.me>
 */
pragma solidity ^0.8;

//Interface that all adapter must inherit..
interface IAdapter {
    //@notice Entry point for Swaps between EIP20 compliant tokens
    struct AdapterState {
        address[] commonTokens;
        //Most dexes have different fee tiers and this variable is used to store acceptable fee tiers in a dex
        //fee tiers are prioritized linearly i.e(from the 0th index-the last index)
        //Another tier may be considered if no pool exists for the previous tier..
        uint256[] feeTiers;
    }

    function Swap(
        address[] memory _tokens,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        bool _reroute
    ) external payable returns (uint256);

    /**
     *Fetches the best price for a swap from _token-In->_token-Out
     *where _tokenIn=_token[0] and _tokenOut=_tokens[lastIndex]
     *A reroute flag which would construct a path between _tokenIn and _tokenOut
     *With commonly traded tokens to make sure there exist pools or liquidity for a trade..
     */
    function computeAmountOut(
        address[] memory _tokens,
        uint256 _amountIn,
        bool _reroute
    ) external view returns (uint256 _amountOut);

    function Name() external view returns (string memory);
}