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
interface IERC20Metadata {
    function name() external view returns (string memory);
}

contract UniswapV2Test is Test {
    Uniswap2Adapter private adapter;
    address _router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address _factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private FLOKI = 0xcf0C122c6b73ff809C693DB761e7BaeBe62b6a2E;
    address private DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private EBTC = 0x661c70333AA1850CcDBAe82776Bb436A0fCfeEfB;
    address private QUANT = 0x4a220E6096B25EADb88358cb44068A3248254675;
    address TRAC = 0xaA7a9CA87d3694B5755f213B5D04094b8d0F0A6F;
    address WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address operator;
    modifier onlyOperator() {
        vm.startPrank(operator);
        _;
        vm.stopPrank();
    }

    constructor() {
        //initializes the uniswap-v2-adapter contracts..
        vm.createSelectFork(vm.envString("MAINNET_RPC"));
        _init();
    }

    /**
     * Key functionalities:
     * Swap
     * ComputeAmountOut
     * Admin Functionalities:
     *       addCTokens
     *       removeCtokens
     */

    function _init() internal {
        adapter = new Uniswap2Adapter(_router, _factory, address(this));
        adapter.addCommonTokens(WETH);
        adapter.addCommonTokens(USDT);
        adapter.addCommonTokens(USDC);
        adapter.addCommonTokens(DAI);
    }

    function testFetchPrice() external view {
        address[] memory tokens = new address[](4);
        tokens[0] = 0xaA7a9CA87d3694B5755f213B5D04094b8d0F0A6F;
        tokens[1] = WETH;
        tokens[2] = STETH;
        tokens[3] = QUANT;

        uint256 _amountOut = adapter.computeAmountOut(tokens, 1e18, true);
        console.log("AMOUNT-RECEIVED FROM SWAP::[%s]", _amountOut);
        console.log("TEST-PASSED");
    }

    function testSwap() external {
        uint256 _amountIn = 1e18;
        uint256 _minAmountOut = 1e10;
        address[] memory _tokens = new address[](5);
        _tokens[0] = TRAC;
        _tokens[1] = WETH;
        _tokens[2] = STETH;
        _tokens[3] = QUANT;
        _tokens[4] = 0xD1B89856D82F978D049116eBA8b7F9Df2f342fF3;
        _issue(_tokens[0], _amountIn);
        uint256 _amountOut = adapter.Swap(
            _tokens,
            _amountIn,
            _minAmountOut,
            address(this),
            true
        );
        assertGt(_amountOut, _minAmountOut);
        console.log("AMOUNT-OUT RECEIVED::[%s]", _amountOut);
    }

    function testAddCToken() external {
        address[] memory _tokens = adapter.getCommonTokens();
        adapter.addCommonTokens(WBTC);
        _tokens = adapter.getCommonTokens();
        assertEq(contains(_tokens, WBTC), true);
    }

    function testRemoveCToken() external {
        address[] memory _tokens = adapter.getCommonTokens();
        address lastToken = _tokens[_tokens.length - 1];
        log_name(lastToken);
        adapter.removeCommonTokens(_tokens.length - 1);
        _tokens = adapter.getCommonTokens();
        assertEq(contains(_tokens, lastToken), false);
    }

    function _issue(address _token, uint256 _amount) internal {
        deal(_token, address(adapter), _amount);
    }

    function log_name(address _token) internal view {
        console.log("TOKEN-NAME:::[%s]", IERC20Metadata(_token).name());
    }

    function contains(
        address[] memory _tokens,
        address _token
    ) internal pure returns (bool) {
        for (uint8 i; i < _tokens.length; i++) {
            if (_tokens[i] == _token) {
                return true;
            }
        }
        return false;
    }
}
