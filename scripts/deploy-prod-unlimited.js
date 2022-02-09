const hre = require("hardhat");
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const UnlimitedModelFactory = await hre.ethers.getContractFactory('UnlimitedModel');

    const UnlimitedModel = await UnlimitedModelFactory.connect(signer).deploy();
    await UnlimitedModel.deployed();
    console.log("UnlimitedModel depolyed to:", UnlimitedModel.address);

    const addresses = {
        UnlimitedModel: UnlimitedModel.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/unlimited-model-mainnet.json`, JSON.stringify(addresses, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
