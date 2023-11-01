//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;

contract dydx {
    //
    receive() external payable {}

    fallback() external payable {}

    function getPrice(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) public view returns (uint256) {}

    function flashLoan(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _payload,
        address caller
    ) external {}

    function singleSwap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external returns (uint256) {}

    function multiSwap(
        uint256 _amountIn,
        address[] memory _path,
        uint256 _amountMin
    ) external returns (uint256) {}
}
