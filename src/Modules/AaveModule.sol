//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;
import "src/Interfaces/IAaveV3.sol";

contract AaveModule {
    address immutable flashLoanModule;
    IPoolAddressesProvider addressProvider;
    address immutable SOR;

    constructor(address _flashloanModule, address _provider, address _sor) {
        flashLoanModule = _flashloanModule;
        addressProvider = IPoolAddressesProvider(_provider);
        SOR = _sor;
    }

    function flashLoan(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _payload,
        address caller
    ) external {
        //Get latest Aave Lending Pool
        uint256[] memory interestRateModes = new uint256[](_tokens.length);
        //Concat caller to payload
        _payload = abi.encodePacked(_payload, caller);
        address _pool = addressProvider.getPool();
        for (uint8 i; i < _tokens.length; i++) {
            //Pay plus fee duhh!! its a flashloan bruh
            interestRateModes[i] = 0;
        }
        IPool(_pool).flashLoan(
            flashLoanModule,
            _tokens,
            _amounts,
            interestRateModes,
            address(0),
            _payload,
            0
        );
    }

    fallback() external {
        if (msg.sender != SOR) {
            revert("Unauthorised Caller");
        }
    }
}
//
