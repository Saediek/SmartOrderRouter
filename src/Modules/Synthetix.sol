//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.0;
import "src/Interfaces/IERC20.sol";
import "src/Interfaces/ISynthetix.sol";
import "src/Libraries/SafeERC20.sol";

contract SynthetixAdapter {
    using SafeERC20 for IERC20;
    struct SynthetixTradeInfo {
        bytes32 sourceCurrencyKey; // Currency key of the token to send
        bytes32 destinationCurrencyKey; // Currency key the token to receive
    }
    address public immutable synthetixExchangerAddress;

    constructor(address _synthetixRouter) {
        synthetixExchangerAddress = _synthetixRouter;
    }

    function _getCurrencyKey(address _token) internal view returns (bytes32) {
        try ISynth(_token).currencyKey() returns (bytes32 key) {
            return key;
        } catch (bytes memory /* data */) {
            revert("Invalid Synth token address");
        }
    }

    function getPrice(
        address _sourceToken,
        address _destinationToken,
        uint256 _sourceQuantity
    ) external view returns (uint256 amountReceived) {
        SynthetixTradeInfo memory synthetixTradeInfo;

        synthetixTradeInfo.sourceCurrencyKey = _getCurrencyKey(_sourceToken);
        synthetixTradeInfo.destinationCurrencyKey = _getCurrencyKey(
            _destinationToken
        );

        (amountReceived, , ) = ISynthetixExchanger(synthetixExchangerAddress)
            .getAmountsForExchange(
                _sourceQuantity,
                synthetixTradeInfo.sourceCurrencyKey,
                synthetixTradeInfo.destinationCurrencyKey
            );
    }

    function singleSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _minOut
    ) external returns (uint256 _amountOut) {
        SynthetixTradeInfo memory synthetixTradeInfo;
        synthetixTradeInfo.sourceCurrencyKey = _getCurrencyKey(_tokenIn);
        synthetixTradeInfo.destinationCurrencyKey = _getCurrencyKey(_tokenOut);
        IERC20(_tokenIn).safeApprove(synthetixExchangerAddress, _amountIn);

        _amountOut = ISynthetixExchanger(synthetixExchangerAddress).exchange(
            address(this),
            synthetixTradeInfo.sourceCurrencyKey,
            _amountIn,
            synthetixTradeInfo.destinationCurrencyKey,
            msg.sender
        );
        if (_amountOut < _minOut) {
            revert("amount  out less than min");
        }
    }

    function multiSwap() external returns (uint256) {}

    fallback() external payable {}

    receive() external payable {}
}
