const hre = require("hardhat");
const basic = require('./basic-model-588.json');

// TST
const TST = '0x1EEfEA9DdB5C2eb16D8422805DB8834677b59425';
// TUSDT
const TUSDT = '0xF02Efd44B57d143c38A329dD299683bf24Cf8aE0';
// NETT
const NETT = '0x8127bd4C0e71d5B1f4B28788bb8C4708b51934F9';
// Metis
const Metis = '0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000';

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const basic_nett_without_whitelist = {
        tokens: [
            TST,
            TUSDT,
            NETT
        ],
        adminAddress: signer.address,
        time: [
            Math.round(Date.now() / 1000) + 5 * 60,
            30 * 60,
            5 * 60,
            30 * 60
        ],
        decimals: ['1000000000000000000', '1000000'],
        // 10000 TST
        _salesAmount: '10000000000000000000000',
        // 100 NETT
        _maxPerUser: '100000000000000000000',
        // $2 * 1e18
        _price: '2000000000000000000',
        // 100 NETT
        _minStakedCap: '100000000000000000000',
        // 1000 NETT
        _maxStakedCap: '1000000000000000000000',
        _isWhitelist: false
    }

    const basic_nett_with_whitelist = {
        tokens: [
            TST,
            TUSDT,
            NETT
        ],
        adminAddress: signer.address,
        time: [
            Math.round(Date.now() / 1000) + 5 * 60,
            30 * 60,
            5 * 60,
            30 * 60
        ],
        decimals: ['1000000000000000000', '1000000'],
        // 10000 TST
        _salesAmount: '10000000000000000000000',
        // 100 NETT
        _maxPerUser: '100000000000000000000',
        // $2 * 1e18
        _price: '2000000000000000000',
        // 100 NETT
        _minStakedCap: '100000000000000000000',
        // 1000 NETT
        _maxStakedCap: '1000000000000000000000',
        _isWhitelist: true
    };

    const basic_metis_without_whitelist = {
        tokens: [
            TST,
            TUSDT,
            Metis
        ],
        adminAddress: signer.address,
        time: [
            Math.round(Date.now() / 1000) + 5 * 60,
            30 * 60,
            5 * 60,
            30 * 60
        ],
        decimals: ['1000000000000000000', '1000000'],
        // 10000 TST
        _salesAmount: '10000000000000000000000',
        // 100 Metis
        _maxPerUser: '100000000000000000000',
        // $1 * 1e18
        _price: '1000000000000000000',
        // 100 Metis
        _minStakedCap: '100000000000000000000',
        // 1000 Metis
        _maxStakedCap: '1000000000000000000000',
        _isWhitelist: false
    };

    const basic_metis_with_whitelist = {
        tokens: [
            TST,
            TUSDT,
            Metis
        ],
        adminAddress: signer.address,
        time: [
            Math.round(Date.now() / 1000) + 5 * 60,
            30 * 60,
            5 * 60,
            30 * 60
        ],
        decimals: ['1000000000000000000', '1000000'],
        // 10000 TST
        _salesAmount: '10000000000000000000000',
        // 100 Metis
        _maxPerUser: '100000000000000000000',
        // $1 * 1e18
        _price: '1000000000000000000',
        // 100 Metis
        _minStakedCap: '100000000000000000000',
        // 1000 Metis
        _maxStakedCap: '1000000000000000000000',
        _isWhitelist: true
    };

    // console.log(
    //     basic_nett_without_whitelist.tokens,
    //     basic_nett_without_whitelist.adminAddress,
    //     basic_nett_without_whitelist.time,
    //     basic_nett_without_whitelist._salesAmount,
    //     basic_nett_without_whitelist._maxPerUser,
    //     basic_nett_without_whitelist._price,
    //     basic_nett_without_whitelist._minStakedCap,
    //     basic_nett_without_whitelist._maxStakedCap,
    //     basic_nett_without_whitelist._isWhitelist
    // );
    // console.log(
    //     basic_nett_with_whitelist.tokens,
    //     basic_nett_with_whitelist.adminAddress,
    //     basic_nett_with_whitelist.time,
    //     basic_nett_with_whitelist._salesAmount,
    //     basic_nett_with_whitelist._maxPerUser,
    //     basic_nett_with_whitelist._price,
    //     basic_nett_with_whitelist._minStakedCap,
    //     basic_nett_with_whitelist._maxStakedCap,
    //     basic_nett_with_whitelist._isWhitelist
    // );

    // console.log(
    //     basic_metis_without_whitelist.tokens,
    //     basic_metis_without_whitelist.adminAddress,
    //     basic_metis_without_whitelist.time,
    //     basic_metis_without_whitelist._salesAmount,
    //     basic_metis_without_whitelist._maxPerUser,
    //     basic_metis_without_whitelist._price,
    //     basic_metis_without_whitelist._minStakedCap,
    //     basic_metis_without_whitelist._maxStakedCap,
    //     basic_metis_without_whitelist._isWhitelist
    // )

    // console.log(
    //     basic_metis_with_whitelist.tokens,
    //     basic_metis_with_whitelist.adminAddress,
    //     basic_metis_with_whitelist.time,
    //     basic_metis_with_whitelist._salesAmount,
    //     basic_metis_with_whitelist._maxPerUser,
    //     basic_metis_with_whitelist._price,
    //     basic_metis_with_whitelist._minStakedCap,
    //     basic_metis_with_whitelist._maxStakedCap,
    //     basic_metis_with_whitelist._isWhitelist
    // )

    const BasicModelFactory = await hre.ethers.getContractFactory('BasicModel');

    const BasicModel = await BasicModelFactory.attach(basic.BasicModel);

    console.log('adding pad using NETT without whitelist...');
    await BasicModel.connect(signer).addPad(
        basic_nett_without_whitelist.tokens,
        basic_nett_without_whitelist.adminAddress,
        basic_nett_without_whitelist.time,
        basic_nett_without_whitelist.decimals,
        basic_nett_without_whitelist._salesAmount,
        basic_nett_without_whitelist._maxPerUser,
        basic_nett_without_whitelist._price,
        basic_nett_without_whitelist._minStakedCap,
        basic_nett_without_whitelist._maxStakedCap,
        basic_nett_without_whitelist._isWhitelist
    );
    console.log('added pad using NETT without whitelist');

    console.log('adding pad using NETT with whitelist...');
    await BasicModel.connect(signer).addPad(
        basic_nett_with_whitelist.tokens,
        basic_nett_with_whitelist.adminAddress,
        basic_nett_with_whitelist.time,
        basic_nett_with_whitelist.decimals,
        basic_nett_with_whitelist._salesAmount,
        basic_nett_with_whitelist._maxPerUser,
        basic_nett_with_whitelist._price,
        basic_nett_with_whitelist._minStakedCap,
        basic_nett_with_whitelist._maxStakedCap,
        basic_nett_with_whitelist._isWhitelist
    );
    console.log('added pad using NETT with whitelist');

    await BasicModel.connect(signer).addPad(
        basic_metis_without_whitelist.tokens,
        basic_metis_without_whitelist.adminAddress,
        basic_metis_without_whitelist.time,
        basic_metis_without_whitelist.decimals,
        basic_metis_without_whitelist._salesAmount,
        basic_metis_without_whitelist._maxPerUser,
        basic_metis_without_whitelist._price,
        basic_metis_without_whitelist._minStakedCap,
        basic_metis_without_whitelist._maxStakedCap,
        basic_metis_without_whitelist._isWhitelist
    );
    console.log('added pad using Metis without whitelist');

    console.log('adding pad using Metis with whitelist...');
    await BasicModel.connect(signer).addPad(
        basic_metis_with_whitelist.tokens,
        basic_metis_with_whitelist.adminAddress,
        basic_metis_with_whitelist.time,
        basic_metis_with_whitelist.decimals,
        basic_metis_with_whitelist._salesAmount,
        basic_metis_with_whitelist._maxPerUser,
        basic_metis_with_whitelist._price,
        basic_metis_with_whitelist._minStakedCap,
        basic_metis_with_whitelist._maxStakedCap,
        basic_metis_with_whitelist._isWhitelist
    );
    console.log('added pad using Metis with whitelist');

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
