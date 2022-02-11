const hre = require("hardhat");
const unlimited = require('./unlimited-model-mainnet.json');

const NETT = '0x90fe084f877c65e1b577c7b2ea64b8d8dd1ab278';
const Metis = '0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000';
const USDT = '0xbb06dca3ae6887fabf931640f67cab3e3a16f4dc';
const MINES = '0xE9Aa15a067b010a4078909baDE54F0C6aBcBB852';
const padAdmin = '0x5f961a57d6ca9E4E51d09b128DB3A88815415d8e';

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[1];
    console.log('signer:', signer.address);

    const unlimited_nett_without_whitelist = {
        tokens: [
            MINES,
            USDT,
            NETT
        ],
        adminAddress: padAdmin,
        time: [
            // start time Feb.10 UTC 15:00
            1644505200,
            // staking period, 2 days
            2 * 24 * 60 * 60,
            // vesting period, 7 days
            7 * 24 * 60 * 60,
            // cashing period, 2 days
            2 * 24 * 60 * 60
        ],
        decimals: ['1000000000000000000', '1000000'],
        // 750,000 MINES
        _salesAmount: '750000000000000000000000',
        // $0.2 * 1e18
        _price: '200000000000000000',
        _minStakedUserAmount: 150,
        // 1,500 NETT
        _minStakedCap: '1500000000000000000000',
        // 1,500 NETT
        _maxStakedCap: '1500000000000000000000',
        _isWhitelist: false
    }

    const unlimited_metis_with_whitelist = {
        tokens: [
            MINES,
            USDT,
            Metis
        ],
        adminAddress: padAdmin,
        time: [
            // start time Feb.10 UTC 15:00
            1644505200,
            // staking period, 2 days
            2 * 24 * 60 * 60,
            // vesting period, 7 days
            7 * 24 * 60 * 60,
            // cashing period, 2 days
            2 * 24 * 60 * 60
        ],
        decimals: ['1000000000000000000', '1000000'],
        // 1,750,000 MINES
        _salesAmount: '1750000000000000000000000',
        // $0.2 * 1e18
        _price: '200000000000000000',
        _minStakedUserAmount: 300,
        // 300 Metis
        _minStakedCap: '300000000000000000000',
        // 300 Metis
        _maxStakedCap: '300000000000000000000',
        _isWhitelist: true
    }

    const UnlimitedModelFactory = await hre.ethers.getContractFactory('UnlimitedModel');

    const UnlimitedModel = await UnlimitedModelFactory.attach(unlimited.UnlimitedModel);

    console.log('adding pad using NETT without whitelist...');
    await UnlimitedModel.connect(signer).addPad(
        unlimited_nett_without_whitelist.tokens,
        unlimited_nett_without_whitelist.adminAddress,
        unlimited_nett_without_whitelist.time,
        unlimited_nett_without_whitelist.decimals,
        unlimited_nett_without_whitelist._salesAmount,
        unlimited_nett_without_whitelist._price,
        unlimited_nett_without_whitelist._minStakedUserAmount,
        unlimited_nett_without_whitelist._minStakedCap,
        unlimited_nett_without_whitelist._maxStakedCap,
        unlimited_nett_without_whitelist._isWhitelist
    );
    console.log('added pad using NETT without whitelist');

    console.log('adding pad using Metis with whitelist...');
    await UnlimitedModel.connect(signer).addPad(
        unlimited_metis_with_whitelist.tokens,
        unlimited_metis_with_whitelist.adminAddress,
        unlimited_metis_with_whitelist.time,
        unlimited_metis_with_whitelist.decimals,
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