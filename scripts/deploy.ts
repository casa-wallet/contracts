import { ethers } from "hardhat";

async function main() {
    const factory = await ethers.deployContract("Factory")
    await factory.waitForDeployment()

    console.log(`Factory deployed: ${factory.target}`)
    console.log(`Wallet deployed: ${await factory.implementation()}`)
}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
