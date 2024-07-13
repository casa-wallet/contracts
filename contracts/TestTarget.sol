// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract TestTarget {
    event Call(address caller, uint256 value, bytes data);

    fallback() external payable {
        emit Call(msg.sender, msg.value, msg.data);
    }
}
