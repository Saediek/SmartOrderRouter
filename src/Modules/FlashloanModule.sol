//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;
import "src/Interfaces/IUniswapV2.sol";
import "src/Interfaces/IERC20.sol";
import "src/Libraries/SafeERC20.sol";
import "src/Interfaces/IUniswapV3.sol";

contract FlashloanModule {
    using SafeERC20 for IERC20;
    address immutable SmartOrderRouter;

    constructor(address _router) {
        SmartOrderRouter = _router;
    }

    function uniswapV2Call(
        address _caller,
        uint256 _amount0,
        uint256 _amount1,
        bytes memory _data
    ) external {
        if (_caller != SmartOrderRouter) {
            revert("Unauthorised Caller");
        }
        (uint256 _reserve0, uint256 _reserve1, ) = IUniswapV2Pair(msg.sender)
            .getReserves();
        uint256 k_Before = _reserve0 * _reserve1;
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        (address[] memory target, bytes[] memory _payload, address caller) = abi
            .decode(_data, (address[], bytes[], address));
        if (target.length != _payload.length) {
            revert("Mismatched length");
        }
        for (uint8 i; i < target.length; i++) {
            (bool sucess, ) = target[i].call(_payload[i]);
            if (!sucess) {
                revert("call failed");
            }
        }
        _amount0 = _amount0 + (300 * _amount0) / 10000;
        _amount1 = _amount1 + (300 * _amount1) / 10000;
        IERC20(token0).safeTransfer(msg.sender, _amount0);
        IERC20(token1).safeTransfer(msg.sender, _amount1);
        uint256 k_After = IERC20(token0).balanceOf(msg.sender) *
            IERC20(token1).balanceOf(msg.sender);
        if (k_After < k_Before) {
            revert("Delta-K");
        }
        IERC20(token0).safeTransfer(
            caller,
            IERC20(token0).balanceOf(address(this))
        );
        IERC20(token1).safeTransfer(
            caller,
            IERC20(token1).balanceOf(address(this))
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {}

    function uniswapV3FlashCallback(
        uint24 _fee0,
        uint24 _fee1,
        bytes memory _payload
    ) external {
        (
            address[] memory _target,
            bytes[] memory _payloads,
            address _caller
        ) = abi.decode(_payload, (address[], bytes[], address));
        if (_target.length != _payloads.length) {
            revert("Mismatched-length");
        }
        address _token0 = IUniswapPool(msg.sender).token0();
        address _token1 = IUniswapPool(msg.sender).token1();
        uint256 _balance0Before = IERC20(_token0).balanceOf(address(this));
        uint256 _balance1Before = IERC20(_token1).balanceOf(address(this));
        for (uint8 i; i < _target.length; i++) {
            (bool sucess, ) = _target[1].call(_payloads[1]);
            if (!sucess) {
                revert("Flashloan-failed");
            }
        }
        if (_balance0Before != 0) {
            IERC20(_token0).safeTransfer(msg.sender, _balance0Before + _fee0);
        }
        if (_balance1Before != 0) {
            IERC20(_token1).safeTransfer(msg.sender, _balance1Before + _fee1);
        }
        uint256 _currentBal0 = IERC20(_token0).balanceOf(address(this));
        uint256 _currentBal1 = IERC20(_token1).balanceOf(address(this));
        if (_currentBal0 != 0) {
            IERC20(_token0).safeTransfer(_caller, _currentBal0);
        }
        if (_currentBal1 != 0) {
            IERC20(_token1).safeTransfer(_caller, _currentBal1);
        }
    }
}
