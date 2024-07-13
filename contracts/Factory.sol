// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {Wallet} from "./Wallet.sol";

contract SmartFactory {
    Wallet public implementation;

    constructor() {
        implementation = new Wallet();
        implementation.initialize(address(this));
    }

    function createWallet(
        address owner,
        uint256 index
    ) external returns (address wallet) {
        wallet = Clones.cloneDeterministic(
            address(implementation),
            keccak256(abi.encodePacked(index, owner))
        );
        Wallet(payable(wallet)).initialize(owner);
    }

    function getWallet(
        address owner,
        uint256 index
    ) external view returns (bool exists, address wallet) {
        wallet = Clones.predictDeterministicAddress(
            address(implementation),
            keccak256(abi.encodePacked(index, owner))
        );

        uint256 size;
        assembly {
            size := extcodesize(wallet)
        }
        exists = size > 0;
    }
}
