import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import type { ContractTransactionResponse } from "ethers";

const DOMAIN = {
  name: "CASA"
}

const TYPES = {
  Call: [
    { name: "nonce", type: "uint128" },
    { name: "chainId", type: "uint128" },
    { name: "from", type: "address" },
    { name: "to", type: "address" },
    { name: "value", type: "uint256" },
    { name: "data", type: "bytes" },
  ],
  Fee: [
    { name: "from", type: "address" },
    { name: "chainId", type: "uint256" },
    { name: "token", type: "address" },
    { name: "amount", type: "uint256" },
    { name: "recipient", type: "address" },
  ],
  CASA: [
    { name: "call", type: "Call" },
    { name: "fee", type: "Fee" },
  ],
}

describe("Wallet", function () {
  async function deploy() {
    const [owner, paymaster] = await ethers.getSigners();
    const wallet = await ethers.deployContract("Wallet")
    await wallet.initialize(owner)

    const testTarget = await ethers.deployContract("TestTarget")

    return { wallet, owner, paymaster, testTarget }
  }

  describe("Call", function () {
    it("Should execute call", async function () {
      const { wallet, owner, testTarget, paymaster } = await loadFixture(deploy);

      const call = {
        nonce: await wallet.nonces(wallet),
        chainId: (await ethers.provider.getNetwork()).chainId,
        from: await wallet.getAddress(),
        to: await testTarget.getAddress(),
        value: 0n,
        data: ethers.randomBytes(32)
      }
      const fee = {
        from: await wallet.getAddress(),
        chainId: (await ethers.provider.getNetwork()).chainId,
        token: '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
        amount: ethers.parseEther("0.1"),
        recipient: paymaster.address
      }

      let tx = wallet.connect(owner).casaCall(call, ethers.randomBytes(32), ethers.randomBytes(0))
      await expect(tx).to.be.not.reverted;
      let r = await (await tx).wait()
      let callLog = testTarget.interface.parseLog(r?.logs.find(l => l.address === testTarget.target)!)
      expect(callLog?.args).to.be.deep.eq([call.from, call.value, ethers.hexlify(call.data)])

      const sig = await owner.signTypedData(DOMAIN, TYPES, { call, fee })
      call.nonce = await wallet.nonces(wallet)
      tx = wallet.connect(paymaster).casaCall(call, await wallet.calculateFeeHash(fee), sig)
      callLog = testTarget.interface.parseLog(r?.logs.find(l => l.address === testTarget.target)!)
      expect(callLog?.args).to.be.deep.eq([call.from, call.value, ethers.hexlify(call.data)])
    })
  })

  describe("EIP-712", function () {
    it("Sholud correct calculate hashes", async function () {
      const { wallet, owner } = await loadFixture(deploy);

      const casa = {
        call: {
          nonce: await wallet.nonces(wallet),
          chainId: (await ethers.provider.getNetwork()).chainId,
          from: await wallet.getAddress(),
          to: owner.address,
          value: 0,
          data: ethers.randomBytes(0) // 0x
        },
        fee: {
          from: await wallet.getAddress(),
          chainId: 123,
          token: '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
          amount: ethers.parseEther("0.1"),
          recipient: owner.address
        }
      }

      const callHash = ethers.TypedDataEncoder.hashStruct("Call", TYPES, casa.call);
      expect(await wallet.calculateCallHash(casa.call)).to.be.eq(callHash, "call hash")

      const feeHash = ethers.TypedDataEncoder.hashStruct("Fee", TYPES, casa.fee);
      expect(await wallet.calculateCallHash(casa.call)).to.be.eq(callHash, "fee hash")

      const casaHash = ethers.TypedDataEncoder.hash(DOMAIN, TYPES, casa)
      expect(await wallet.calculateCasaHash(callHash, feeHash)).to.be.eq(casaHash, "casa hash")
    })

  })
});
