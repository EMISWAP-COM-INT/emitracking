// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {
    uint8 private constant INIT_DECIMALS = 6;
    uint256 private constant INITIAL_SUPPLY = 10000000000 * (10**INIT_DECIMALS);

    function decimals() public pure override returns (uint8) {
        return INIT_DECIMALS;
    }

    constructor() ERC20("USDT token", "USDT") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
