pragma solidity ^0.8.0;
import "src/Interfaces/IBalancer.sol";

contract BalancerV2Module {
    IVault public immutable vault;
    address public immutable flashLoanModule;

    constructor(address _balancerVault, address _flashloanModule) {
        vault = IVault(_balancerVault);
        flashLoanModule = _flashloanModule;
    }

    /**
     *Get price of _token0 in terms of the quote token
     *_token0 address of the base token
     * _token1 address of the quote token
     * _amountIn amount of the base token.
     *The amountOut of a given amountIn is gotten by the formula
     *A.Out=B.Out*(1-(B.In/B.In+A.In(1-fee))^W.In/W.Out);
     *B.Out,A.Out,W.Out=(Balance of tokenOut,Amount of tokenOut,Weight of tokenOut in the pool).
     *B.In,A.In,W.In=(Balance of tokenIn,Amount of tokenIn,Weight of tokenIn in the pool).
     */
    function getPrice(
        address _token0,
        address _token1,
        uint _amountIn
    ) external view returns (uint256 _Ao) {
        uint256 _Bo = IERC20(_token1).balanceOf(address(vault));
        uint256 _Wo;
        uint256 _Wi;
        uint256 _Bi = IERC20(_token0).balanceOf(address(vault));
        uint256 _fee;
        uint256 _ratio = _Wi / _Wo;
        uint256 _denominator = _Bi + _amountIn * (1e18 - _fee);
        _Ao = _Bo * (1e18 - (_Bi / _denominator) ** _ratio);
    }

    /*
     *Trade a single token for another token i.e(TokenA->TokenB)
     * _tokenIn address of base Token
     * _tokenOut address of Quote Token
     * _amountIn: An amount of base Token msg.sender is willing to trade
     * _minAmountOut :Minimum amount of quote Token caller is willing to receive
     */

    function singleSwap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) external returns (uint256) {
        bytes32 _poolId = getPoolId(_tokenIn, _tokenOut);
        IVault.SingleSwap memory _singleSwap = IVault.SingleSwap(
            _poolId,
            IVault.SwapKind.GIVEN_IN,
            _tokenIn,
            _tokenOut,
            _amountIn,
            bytes("")
        );
        IVault.FundManagement memory funds = IVault.FundManagement(
            address(this),
            false,
            payable(msg.sender),
            false
        );
        IERC20(_tokenIn).approve(address(vault), _amountIn);
        return vault.swap(_singleSwap, funds, _minAmountOut, block.timestamp);
    }

    //multi-swap method

    function multiSwap(
        uint256 _amountIn,
        address[] memory _path,
        uint256 _amountMin
    ) external returns (uint256) {
        IVault.BatchSwapStep[] memory _step;
        IAsset[] memory _assets = _convertToIAssets(_path);
        int256[] memory limits;
        for (uint8 i; i < _path.length; i++) {
            bytes32 _poolId = getPoolId(_path[i], _path[i + 1]);
            limits[i] = type(int256).max;
            //approve max-amount.

            if (i == 0) {
                _step[i] = IVault.BatchSwapStep(
                    _poolId,
                    i,
                    i + 1,
                    _amountIn,
                    bytes("")
                );
            } else {
                _step[i] = IVault.BatchSwapStep(
                    _poolId,
                    i,
                    i + 1,
                    0,
                    bytes("")
                );
            }
        }
        IVault.FundManagement memory _fundsManagement = IVault.FundManagement(
            address(this),
            false,
            payable(msg.sender),
            false
        );
        int256[] memory _amountOuts = vault.batchSwap(
            IVault.SwapKind.GIVEN_IN,
            _step,
            _assets,
            _fundsManagement,
            limits,
            block.timestamp
        );

        int _minAmount = int(_amountMin);
        int _amountOut = _amountOuts[_amountOuts.length - 1];
        if (_amountOut > 0 && _amountOut >= _minAmount) {
            return uint256(_amountOut);
        } else {
            revert("amountOut less than min-expected Value");
        }
    }

    function flashloan(
        address[] memory _token,
        uint256[] memory _amounts,
        bytes memory _payload,
        address _caller
    ) external {
        _payload = abi.encodePacked(_payload, _caller);
        IFlashLoanRecipient _receipient = IFlashLoanRecipient(flashLoanModule);
        IERC20[] memory _erc20Tokens = _convertToIERC20(_token);

        vault.flashLoan(_receipient, _erc20Tokens, _amounts, _payload);
    }

    //@todo Implement the getter function for poolId of a pool.
    function getPoolId(
        address _tokenIn,
        address _tokenOut
    ) internal view returns (bytes32 _poolId) {}

    function _convertToIERC20(
        address[] memory _tokens
    ) internal pure returns (IERC20[] memory _erc20Tokens) {
        for (uint8 i; i < _tokens.length; i++) {
            _erc20Tokens[i] = IERC20(_tokens[i]);
        }
    }

    function _convertToIAssets(
        address[] memory _tokens
    ) internal pure returns (IAsset[] memory _assets) {
        for (uint8 i; i < _tokens.length; i++) {
            _assets[i] = IAsset(_tokens[i]);
        }
    }
}
