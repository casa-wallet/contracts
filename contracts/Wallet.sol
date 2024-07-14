// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract Wallet is OwnableUpgradeable, NoncesUpgradeable, ERC721Holder {
    error BadChainId();
    error BadFrom();
    error BadTo();
    error BadNonce();
    error BadSignature();
    error AlreadyPaid();

    struct CasaCall {
        uint128 nonce;
        uint128 chainId;
        address from;
        address to;
        uint256 value;
        bytes data;
    }

    struct CasaFee {
        address from;
        uint256 chainId;
        address token;
        uint256 amount;
        address recipient;
    }

    bytes32 constant DOMAIN_SEPARATOR =
        keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name)"),
                keccak256("CASA")
            )
        );

    bytes32 constant CALL_TYPEHASH =
        keccak256(
            "Call(uint128 nonce,uint128 chainId,address from,address to,uint256 value,bytes data)"
        );

    bytes32 constant FEE_TYPEHASH =
        keccak256(
            "Fee(address from,uint256 chainId,address token,uint256 amount,address recipient)"
        );

    bytes32 constant CASA_TYPEHASH =
        keccak256(
            "CASA(Call call,Fee fee)"
            "Call(uint128 nonce,uint128 chainId,address from,address to,uint256 value,bytes data)"
            "Fee(address from,uint256 chainId,address token,uint256 amount,address recipient)"
        );

    using Address for address;
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    mapping(bytes32 => bool) callPaid;

    function initialize(address _owner) external initializer {
        __Ownable_init(_owner);
    }

    function operatorCall(CasaCall calldata call) external {
        if (call.chainId != block.chainid) revert BadChainId();
        if (call.from != address(this)) revert BadFrom();
        if (call.nonce != _useNonce(address(this))) revert BadNonce();

        call.to.functionCallWithValue(call.data, call.value);
    }

    function casaCall(
        CasaCall calldata call,
        bytes32 feeHash,
        bytes calldata signature
    ) external {
        if (call.chainId != block.chainid) revert BadChainId();
        if (call.from != address(this)) revert BadFrom();
        if (call.nonce != _useNonce(address(this))) revert BadNonce();
        if (msg.sender != owner()) {
            bytes32 casaHash = calculateCasaHash(
                calculateCallHash(call),
                feeHash
            );
            if (casaHash.recover(signature) != owner()) revert BadSignature();
        }

        call.to.functionCallWithValue(call.data, call.value);
    }

    function casaFee(
        CasaFee calldata fee,
        bytes32 callHash,
        bytes calldata signature
    ) external {
        bytes32 casaHash = calculateCasaHash(callHash, calculateFeeHash(fee));

        if (fee.from != address(this)) revert BadFrom();
        if (fee.chainId != block.chainid) revert BadChainId();
        if (callPaid[casaHash]) revert AlreadyPaid();
        if (msg.sender != owner() && casaHash.recover(signature) != owner())
            revert BadSignature();

        callPaid[casaHash] = true;
        if (fee.token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            Address.sendValue(payable(fee.recipient), fee.amount);
        } else {
            IERC20(fee.token).safeTransfer(fee.recipient, fee.amount);
        }
    }

    receive() external payable {}

    function calculateCasaHash(
        bytes32 callHash,
        bytes32 feeHash
    ) public pure returns (bytes32) {
        return
            MessageHashUtils.toTypedDataHash(
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(CASA_TYPEHASH, callHash, feeHash))
            );
    }

    function calculateCallHash(
        CasaCall calldata call
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    CALL_TYPEHASH,
                    call.nonce,
                    call.chainId,
                    call.from,
                    call.to,
                    call.value,
                    keccak256(call.data)
                )
            );
    }

    function calculateFeeHash(
        CasaFee calldata fee
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(FEE_TYPEHASH, fee));
    }
}
