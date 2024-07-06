//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;
import "@openzeppelin/token/ERC20/IERC20.sol";
import "../Interfaces/IAdapter.sol";
import "../Interfaces/ICurveRouter.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract CurveAdapter is IAdapter {
    using SafeERC20 for IERC20;
    string public constant Name = "Curve-Adapter";
    ICurveRouter private immutable router;
    address private smartOrderRouter;

    constructor(address _router, address _sor) {
        router = ICurveRouter(_router);
        smartOrderRouter = _sor;
    }

    function Swap(
        address[] memory _tokens,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        bool
    ) external payable returns (uint256) {
        uint256 _tokenOutIndex = _tokens.length - 1;
        //Approve the curveRegistry..
        IERC20(_tokens[0]).forceApprove(address(router), _amountIn);
        return
            router.exchange_with_best_rate(
                _tokens[0],
                _tokens[_tokenOutIndex],
                _amountIn,
                _minAmountOut,
                _receiver
            );
    }

    function computeAmountOut(
        address[] memory _tokens,
        uint256 _amountIn,
        bool
    ) external view returns (uint256 _amountOut) {
        address[8] memory _excludedPools;
        for (uint8 i; i < 8; i++) {
            _excludedPools[i] = address(0);
        }
        (, _amountOut) = router.get_best_rate(
            _tokens[0],
            _tokens[_tokens.length - 1],
            _amountIn,
            _excludedPools
        );
    }
}
