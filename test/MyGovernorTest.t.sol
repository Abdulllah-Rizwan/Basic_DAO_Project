// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test,console} from "../lib/forge-std/src/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {Timelock} from "../src/Timelock.sol";
import {MyToken} from "../src/GovToken.sol";

contract MyGovernorTest is Test {
    MyGovernor myGovernor;
    Box box;
    Timelock timeLock;
    MyToken govToken;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant MIN_DELAY = 3600; 
    uint256 public constant VOTING_DELAY = 1;
    uint256 public constant VOTING_PERIOD = 50400;
    address[] proposers;
    address[] executors;
    uint256[] values;
    bytes[] calldatas;
    address[] target;

    function setUp() public {
        govToken = new MyToken();
        govToken.mint(USER,INITIAL_SUPPLY);
        vm.startPrank(USER);
        govToken.delegate(USER);
        timeLock = new Timelock(MIN_DELAY,proposers,executors);
        myGovernor = new MyGovernor(govToken,timeLock);
    
        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.TIMELOCK_ADMIN_ROLE();

        timeLock.grantRole(proposerRole,address(myGovernor));
        timeLock.grantRole(executorRole,address(0));
        timeLock.revokeRole(adminRole,USER);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timeLock));    
    }

    function testCanUpdateWithoutGoverance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGoveranceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "store 1 in the box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        values.push(0);
        calldatas.push(encodedFunctionCall);
        target.push(address(box));

        //PROPOSE TO THE DAO
        uint256 proposalId = myGovernor.propose(target,values,calldatas,description);

        //VIEW STATE
        console.log("proposal state:",uint256(myGovernor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY+1);
        vm.roll(block.number + VOTING_DELAY+1);

        //VOTE
        string memory reason = "DAOs are powerfull";
        uint8 voteWay = 1;
        vm.prank(USER);
        myGovernor.castVoteWithReason(proposalId, voteWay, reason);
        vm.warp(block.timestamp + VOTING_PERIOD+1);
        vm.roll(block.number + VOTING_PERIOD+1);
        
        //QUEUE the tx
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        myGovernor.queue(target, values, calldatas, descriptionHash);
        vm.roll(block.number + MIN_DELAY+1);
        vm.warp(block.timestamp + MIN_DELAY+1);
        
        //Execute
        myGovernor.execute(target, values,calldatas, descriptionHash);
        console.log("Box value",box.getNumber());
        assert(box.getNumber() == valueToStore);
    }
}

