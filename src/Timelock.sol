// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {TimelockController} from  "../lib/openzepplin-contracts/contracts/governance/extensions/GovernorTimelockControl.sol";

 // minDelay is how long you have to wait before executing
 // proposers is the list of addresses that can propose
 // executors is the list of addresses that can execute
contract Timelock is TimelockController {
    constructor(uint256 minDelay,address[] memory proposers,address[] memory executors) TimelockController(minDelay,proposers,executors){}
}