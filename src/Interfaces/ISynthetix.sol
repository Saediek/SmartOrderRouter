//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;

interface ISynth {
    function currencyKey() external view returns (bytes32);
}

interface ISynthetixExchanger {
    function getAmountsForExchange(
        uint sourceAmount,
        bytes32 sourceCurrencyKey,
        bytes32 destinationCurrencyKey
    )
        external
        view
        returns (uint amountReceived, uint fee, uint exchangeFeeRate);

    function exchange(
        address from,
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address destinationAddress
    ) external returns (uint amountReceived);
}
