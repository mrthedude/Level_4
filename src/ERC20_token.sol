// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract token is ERC20 {
    constructor() ERC20("Level4", "LVL_4") {
        _mint(msg.sender, 100000 * 10 ** decimals());
    }
}
