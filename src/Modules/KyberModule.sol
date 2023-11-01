//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;
import "src/Interfaces/IKyber.sol";
import "src/Libraries/SafeERC20.sol";

/**
 * @title KyberSwap-Module
 * @author Saediek
 *
 *Kyber-Swap Module for interacting with the KyberSwap-protocol
 * exchange contracts. This contract assumes that all tokens
 * being traded are ERC20 tokens.
 */

contract KyberModule {
    using SafeERC20 for *;
    address immutable router;
    uint16 constant poolFee = 3000;
    address immutable feeWallet;

    constructor(address _router, address _feeWallet) {
        router = _router;
        feeWallet = _feeWallet;
    }

    //returns price in precise-Unit

    function getPrice(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) external view returns (uint256 _amountOut) {}

    function singleSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _minOut
    ) external returns (uint256 _amountOut) {
        uint256 balanceBefore = IERC20(_tokenOut).balanceOf(msg.sender);
        IKyberswapRouter.ExactInputSingleParams memory params = IKyberswapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn, // source token to swap (ETH or WETH)
                tokenOut: _tokenOut, // dest token to receive (USDT)
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp, // deadline for the transaction
                amountIn: _amountIn, // the amount of tokenIn to swap
                minAmountOut: _minOut,
                limitSqrtP: 0
            });
        IKyberswapRouter(router).swapExactInputSingle(params);
        _amountOut = IERC20(_tokenOut).balanceOf(msg.sender) - balanceBefore;
    }

    function multiSwap(
        uint256 _amountIn,
        address[] memory _path,
        uint256 _amountMin
    ) external returns (uint256 _amountOut) {
        uint256 balanceBefore = IERC20(_path[0]).balanceOf(msg.sender);

        IKyberswapRouter.SwapDescription memory desc = IKyberswapRouter
            .SwapDescription({
                srcToken: _path[0], // source token to swap
                srcAmount: _amountIn, // the amount of tokenIn to swap
                destToken: _path[_path.length - 1], // dest token to receive
                destAddress: msg.sender, // the recipient of tokenOut
                maxDestAmount: type(uint256).max,
                minConversionRate: _amountMin,
                walletId: new address[](_path.length),
                hint: ""
            });
        IKyberswapRouter(router).tradeWithHint(
            desc,
            payable(msg.sender),
            poolFee,
            payable(feeWallet)
        );
        uint256 balanceAfter = IERC20(_path[_path.length - 1]).balanceOf(
            msg.sender
        );
        _amountOut = balanceAfter - balanceBefore;
    }

    fallback() external {}
}
