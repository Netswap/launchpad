const hre = require("hardhat");
const basic = require('./basic-model-588.json');

// TST
const saleToken = '0x1EEfEA9DdB5C2eb16D8422805DB8834677b59425';
// TUSDT
const paymentToken = '0xF02Efd44B57d143c38A329dD299683bf24Cf8aE0';
// NETT
const stakedToken = '0x8127bd4C0e71d5B1f4B28788bb8C4708b51934F9';

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const params = {
        tokens: [
            saleToken,
            paymentToken,
            stakedToken
        ],
        adminAddress: signer.address,
        time: [
            Math.round(Date.now() / 1000) + 10 * 60,
            24 * 60 * 60,
            24 * 60 * 60,
            24 * 60 * 60
        ],
        // 10000 TST
        _salesAmount: '10000000000000000000000',
        // 100 NETT
        _maxPerUser: '100000000000000000000',
        _price: '2',
        // 100 NETT
        _minStakedCap: '100000000000000000000',
        // 1000 NETT
        _maxStakedCap: '1000000000000000000000',
        _isWhitelist: false
    }

    const BasicModelFactory = await hre.ethers.getContractFactory('BasicModel');

    const BasicModel = await BasicModelFactory.attach(basic.BasicModel);

    await BasicModel.connect(signer).addPad(
        params.tokens,
        params.adminAddress,
        params.time,
        params._salesAmount,
        params._maxPerUser,
        params._price,
        params._minStakedCap,
        params._maxStakedCap,
        params._isWhitelist
    );

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
