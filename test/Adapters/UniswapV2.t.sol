//SPDX-License-Identifier:UNLICENSED
pragma solidity 0.8.24;
import "forge-std/Test.sol";
import "src/Adapters/UniswapV2.sol";
import "forge-std/console2.sol";

/**
 * @title UNISWAPV2-ADAPTER TEST
 * @author @Saediek
 * @notice Unit Test for  uniswap-v2 Adapter..
 */
contract UniswapV2Test is Test {
    Uniswap2Adapter private adapter;
    address _router;
    address _factory;
    address operator;
    modifier onlyOperator() {
        vm.startPrank(operator);
        _;
        vm.stopPrank();
    }

    constructor() {
        //initializes the uniswap-v2-adapter contracts..
        _init();
    }

    function _init() internal {
        adapter = new Uniswap2Adapter(_router, _factory);
        operator = makeAddr("OPERATOR");
    }

    function _addFeeTiers() internal onlyOperator {
      
    }
}
