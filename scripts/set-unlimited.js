const hre = require("hardhat");
const unlimited = require('./unlimited-model-588.json');

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

    const unlimited_nett_without_whitelist = {
        tokens: [
            TST,
            TUSDT,
            NETT
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
        // $2 * 1e18
        _price: '2000000000000000000',
        _minStakedUserAmount: 2,
        // 100 NETT
        _minStakedCap: '100000000000000000000',
        // 1000 NETT
        _maxStakedCap: '1000000000000000000000',
        _isWhitelist: false
    }

    const unlimited_nett_with_whitelist = {
        tokens: [
            TST,
            TUSDT,
            NETT
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
        // $2 * 1e18
        _price: '2000000000000000000',
        _minStakedUserAmount: 2,
        // 100 NETT
        _minStakedCap: '100000000000000000000',
        // 1000 NETT
        _maxStakedCap: '1000000000000000000000',
        _isWhitelist: true
    }

    const unlimited_metis_without_whitelist = {
        tokens: [
            TST,
            TUSDT,
            Metis
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
        // $1 * 1e18
        _price: '1000000000000000000',
        _minStakedUserAmount: 2,
        // 100 Metis
        _minStakedCap: '100000000000000000000',
        // 1000 Metis
        _maxStakedCap: '1000000000000000000000',
        _isWhitelist: false
    }

    const unlimited_metis_with_whitelist = {
        tokens: [
            TST,
            TUSDT,
            Metis
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
        // $1 * 1e18
        _price: '1000000000000000000',
        _minStakedUserAmount: 2,
        // 100 Metis
        _minStakedCap: '100000000000000000000',
        // 1000 Metis
        _maxStakedCap: '1000000000000000000000',
        _isWhitelist: true
    }

    const UnlimitedModelFactory = await hre.ethers.getContractFactory('UnlimitedModel');

    const UnlimitedModel = await UnlimitedModelFactory.attach(unlimited.UnlimitedModel);

    await UnlimitedModel.connect(signer).addPad(
        unlimited_nett_without_whitelist.tokens,
        unlimited_nett_without_whitelist.adminAddress,
        unlimited_nett_without_whitelist.time,
        unlimited_nett_without_whitelist._salesAmount,
        unlimited_nett_without_whitelist._price,
        unlimited_nett_without_whitelist._minStakedUserAmount,
        unlimited_nett_without_whitelist._minStakedCap,
        unlimited_nett_without_whitelist._maxStakedCap,
        unlimited_nett_without_whitelist._isWhitelist
    );
    console.log('added pad using NETT without whitelist');

    await UnlimitedModel.connect(signer).addPad(
        unlimited_nett_with_whitelist.tokens,
        unlimited_nett_with_whitelist.adminAddress,
        unlimited_nett_with_whitelist.time,
        unlimited_nett_with_whitelist._salesAmount,
        unlimited_nett_with_whitelist._price,
        unlimited_nett_with_whitelist._minStakedUserAmount,
        unlimited_nett_with_whitelist._minStakedCap,
        unlimited_nett_with_whitelist._maxStakedCap,
        unlimited_nett_with_whitelist._isWhitelist
    );
    console.log('added pad using NETT with whitelist');

    await UnlimitedModel.connect(signer).addPad(
        unlimited_metis_without_whitelist.tokens,
        unlimited_metis_without_whitelist.adminAddress,
        unlimited_metis_without_whitelist.time,
        unlimited_metis_without_whitelist._salesAmount,
        unlimited_metis_without_whitelist._price,
        unlimited_metis_without_whitelist._minStakedUserAmount,
        unlimited_metis_without_whitelist._minStakedCap,
        unlimited_metis_without_whitelist._maxStakedCap,
        unlimited_metis_without_whitelist._isWhitelist
    );
    console.log('added pad using Metis without whitelist');

    await UnlimitedModel.connect(signer).addPad(
        unlimited_metis_with_whitelist.tokens,
        unlimited_metis_with_whitelist.adminAddress,
        unlimited_metis_with_whitelist.time,
        unlimited_metis_with_whitelist._salesAmount,
        unlimited_metis_with_whitelist._price,
        unlimited_metis_with_whitelist._minStakedUserAmount,
        unlimited_metis_with_whitelist._minStakedCap,
        unlimited_metis_with_whitelist._maxStakedCap,
        unlimited_metis_with_whitelist._isWhitelist
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
