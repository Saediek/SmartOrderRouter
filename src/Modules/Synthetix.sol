//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.0;
import "src/Interfaces/ISynthetix.sol";

contract SynthetixAdapter {
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
}
