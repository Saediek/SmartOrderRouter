//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8;

library Slots {
    struct AddressStorage {
        address value;
    }
    // Write to any slot in the storage of your contracts

    function writeToSlot(bytes32 _slot, address _addr) internal {
        readFromSlot(_slot).value = _addr;
    }

    function readFromSlot(
        bytes32 _slot
    ) internal pure returns (AddressStorage storage r) {
        assembly {
            r.slot := _slot
        }
    }
}
