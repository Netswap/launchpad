const hre = require("hardhat");
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const BasicModelFactory = await hre.ethers.getContractFactory('BasicModel');

    const BasicModel = await BasicModelFactory.connect(signer).deploy();
    await BasicModel.deployed();
    console.log("BasicModel depolyed to:", BasicModel.address);

    const addresses = {
        BasicModel: BasicModel.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/basic-model-mainnet.json`, JSON.stringify(addresses, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
