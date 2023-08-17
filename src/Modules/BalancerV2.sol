//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.0;
import "src/Interfaces/IBalancer.sol";

contract BalancerV2Module {
    IVault public immutable vault;

    constructor(address _balancerVault) {
        vault = IVault(_balancerVault);
    }

    /**
     *Get price of _token0 in terms of the quote token
     *_token0 address of the base token
     * _token1 address of the quote token
     * _amountIn amount of the base token.
     */
    function getPrice(
        address _token0,
        address _token1,
        uint _amountIn
    ) external returns (uint256) {
        bytes32 _poolId = getPoolId(_token0, _token1);
        IVault.SingleSwap memory singleSwap = IVault.SingleSwap(
            _poolId,
            IVault.SwapKind.GIVEN_IN,
            _token0,
            _token1,
            _amountIn,
            ""
        );
        IVault.FundManagement memory funds = IVault.FundManagement(
            address(this),
            false,
            payable(msg.sender),
            false
        );
        return vault.querySwap(singleSwap, funds);
    }

    /*
     *Trade a single token for another token i.e(TokenA->TokenB)
     * _tokenIn address of base Token
     * _tokenOut address of Quote Token
     * _amountIn: An amount of base Token msg.sender is willing to trade
     * _minAmountOut :Minimum amount of quote Token caller is willing to receive
     */

    function SingleSwap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) external returns (uint256) {
        bytes32 _poolId = getPoolId(_tokenIn, _tokenOut);
        IVault.SingleSwap memory singleSwap = IVault.SingleSwap(
            _poolId,
            IVault.SwapKind.GIVEN_IN,
            _tokenIn,
            _tokenOut,
            _amountIn,
            ""
        );
        IVault.FundManagement memory funds = IVault.FundManagement(
            address(this),
            false,
            payable(msg.sender),
            false
        );
        IERC20(_tokenIn).approve(address(vault), _amountIn);
        return vault.swap(singleSwap, funds, _minAmountOut, block.timestamp);
    }

    function multiSwap(
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) external returns (uint256) {}

    function flashloan(
        address[] memory _token,
        uint256[] memory _amounts,
        bytes memory _payload
    ) external returns (uint256) {}

    function getPoolId(
        address _tokenIn,
        address _tokenOut
    ) internal view returns (bytes32 _poolId) {}
}
