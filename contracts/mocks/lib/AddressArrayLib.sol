//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AddressArrayLib {
    function deleteItem(address[] storage self, address item) internal returns (bool) {
        uint256 length = self.length;
        for (uint256 i = 0; i < length; i++) {
            if (self[i] == item) {
                uint256 newLength = self.length - 1;
                if (i != newLength) {
                    self[i] = self[newLength];
                }

                self.pop();

                return true;
            }
        }
        return false;
    }

    function contains(address[] storage self, address item) internal view returns (bool) {
        for (uint256 i = 0; i < self.length; i++) {
            if (self[i] == item) {
                return true;
            }
        }
        return false;
    }
}