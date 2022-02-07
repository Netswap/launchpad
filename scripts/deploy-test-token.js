const hre = require("hardhat");
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const TestERC20 = await hre.ethers.getContractFactory('TestERC20');

    const saleToken = await TestERC20.connect(signer).deploy('Test Sale Token 2', 'TST2', 18);
    await saleToken.deployed();
    console.log("sale token depolyed to:", saleToken.address);

    const addresses = {
        TST: saleToken.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/test-sale-token-2-588.json`, JSON.stringify(addresses, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
