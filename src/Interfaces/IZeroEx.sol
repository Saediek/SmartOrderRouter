/**
 * SPDX-License-Identifier:UNLICENSED
 * @author:<Saediek>
 */
import "@openzeppelin/token/ERC20/IERC20.sol";
pragma solidity ^0.8;

interface IZeroEx {
    enum ProtocolFork {
        PancakeSwap,
        PancakeSwapV2,
        BakerySwap,
        SushiSwap,
        ApeSwap,
        CafeSwap,
        CheeseSwap,
        JulSwap
    }

    function sellToPancakeSwap(
        IERC20[] calldata tokens,
        uint256 sellAmount,
        uint256 minBuyAmount,
        ProtocolFork fork
    ) external payable returns (uint256 buyAmount);
}
