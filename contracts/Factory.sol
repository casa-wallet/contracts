// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {Wallet} from "./Wallet.sol";

contract Factory {
    Wallet public implementation;

    constructor() {
        implementation = new Wallet();
        implementation.initialize(address(this));
    }

    function createWalletAndCall(
        address owner,
        uint256 index,
        Wallet.CasaCall calldata call
    ) external returns (address wallet) {
        wallet = createWallet(owner, index);
        Wallet(payable(wallet)).operatorCall(call);
    }

    function createWallet(
        address owner,
        uint256 index
    ) public returns (address wallet) {
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

        exists = wallet.code.length > 0;
    }
}
