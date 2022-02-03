# BasicModel

###### BasicModel contract for Primary Tier of Launchpad
---

This contract is responsible for conducting a token sale with a staking cap for per users and total. The allocation for per users is dependent on their share of total staked token amount. No participation fee is charged in Primary Tier.

---

## ENUM

```solidity
enum PadPeriod {
    Prepare,
    Staking,
    Vesting,
    Cashing,
    Ended
}

enum PadStatus {
    Success,
    Fail
}
```
`PadPeriod` defined five period flags to identify current period of each pads.

`PadStatus` defined two status to identify current status of each pads.

## STURCT
```solidity
struct PadTime {
    // Start time
    uint256 startTime;
    // The end time for staking
    uint256 stakingEndTime;
    // The end time for vesting
    uint256 vestingEndTime;
    // The end time for cashing
    uint256 cashingEndTime;
}

struct PadVault {
    // Vault contract for sale token
    SaleTokenVault saleTokenVault;
    // Vault contract for raised token
    RaisedTokenVault raisedTokenVault;
}

struct PadInfo{
    // Token for sale
    IERC20 saleToken;
    // Token for payment, can be zero address, means that the sale token will be airdropped to staked users
    IERC20 paymentToken;
    // Token for staking
    IERC20 stakedToken;
    // Total amount of sale token to sell
    uint256 salesAmount;
    // Total amount of staked token
    uint256 stakedAmount;
    // Total amount of staked users
    uint256 stakedUserAmount;
    // Total amount of cashed sale token
    uint256 cashedAmount;
    // Total amount of raised payment token
    uint256 raisedAmount;
    // Max stake amount for per user
    uint256 maxPerUser;
    // Relative to USD
    uint256 price;
    // The min stake amount requirement for token sale
    uint256 minStakedCap;
    // The max stake amount for token sale
    uint256 maxStakedCap;
    // If this pad require whitelist
    bool isWhitelist;
}

struct UserInfo{
    uint256 stakeAmount;
    uint256 allocation;
}
```
`PadTime` defined four time points for each pads.

`PadVault` defined two valuts for each pads, which stored sale tokens and raised tokens.

`PadInfo` defined serveral basic infomation for each pads.

`UserInfo` defined stake amount and allocation for each users on a specific pad.

## Public variables

### padInfo

> `PadInfo[] public padInfo;`

This is a `PadInfo` array stored basic information for each pads.

### isExistedSaleToken

> `mapping(address => bool) public isExistedSaleToken;`

This is a mapping to check if the sale token has been created to a pad. Multiple pads are allowed to be created for the same sale token.

### pidsOfSaleToken

> `mapping(address => uint256[]) public pidsOfSaleToken;`

This is a mapping stored pad ids for a specific sale token.

### padAdmin

> `mapping(uint256 => address) public padAdmin;`

This is a mapping stored a pad admin for each pads.

### userInfo

> `mapping(uint256 => mapping(address => UserInfo)) public userInfo;`

This is a mapping stored `UserInfo` for each users corresponding to a specific pad.

### whitelist

> `mapping(uint256 => mapping(address => bool)) public whitelist;`

This is a mapping to check if a specific address whitelisted to a specific pad.

### PRICE_DECIMALS

> `uint256 constant public PRICE_DECIMALS = 1e18;`

This is decimals used for sale token price, we define this constant as 10^18.

## MUTATIVE FUNCTIONS

### stake

> `function stake(uint256 _pid, uint256 _amount) public onlyWhilteList(_pid)`

Function for users to stake required token to the model contract to get allocation during staking period.

### claim

> `function claim(uint256 _pid, uint256 _amount) public`

Function for users to claim back their staked tokens in three situations:

- During staking period
- Pad failed after staking period
- After cashing period

### cash

> `function cash(uint256 _pid) public`

Function for users to cash sale token by paying `paymentToken` and claim back staked token during cashing period.

The sale token will send from a `saleTokenVault` created when a pad added.

The raised token will be sent to a `raisedTokenVault` created when a pad added.

## VIEW FUNCTIONS

### padLength

> `function padLength() public view returns (uint256)`

Return the pad length of all pads.

### calcAllocation

> `function calcAllocation(uint256 _pid) public view returns (uint256)`

Calculate the allocation of `msg.sender` corresponding to a specific pad.

### padPeriod

> `function padPeriod(uint256 _pid) public view returns (PadPeriod)`

Return current period of a specific pad.

### padStatus

> `function padStatus(uint256 _pid) public view returns (PadStatus)`

Return current status of a specific pad. Only the pad with total staked amount reached `minStakedCap` can be marked as a success pad.

### getPadTime

> `function getPadTime(uint256 _pid) public view returns (uint256 startTime, uint256 stakingEndTime, uint256 vestingEndTime, uint256 cashingEndTime)`

Return four time points of a specific pad.

### getPadVault

> `function getPadVault(uint256 _pid) public view returns (address saleTokenVault, address raisedTokenVault)`

Return two vaults of a specific pad.

### getPids

> `function getPids(address _saleToken) public view returns (uint256[] memory)`

Return id of pads corresponding a specific sale token.

## RESTRICTED FUNCTIONS

### addPad

> `function addPad(address[] memory tokens, address _adminAddress, uint256[] memory time, uint256 _salesAmount, uint256 _maxPerUser, uint256 _price, uint256 _minStakedCap, uint256 _maxStakedCap, bool _isWhitelist) public onlyOwner`

Owner use this function to add a new pad of BasicModel.

### depositSaleToken

> `function depositSaleToken(uint256 _pid) external onlyAdmin onlyPadAdmin(_pid)`

Pad admin use this function to deposit sale tokens to the sale token vault of a specific pad.

### withdrawRemainingSaleToken

> `function withdrawRemainingSaleToken(uint256 _pid, address _recipient) external onlyAdmin onlyPadAdmin(_pid)`

Pad admin use this function to withdraw unsold sale token from the sale token vault of a specific pad.

### withdrawRaisedToken

> `function withdrawRaisedToken(uint256 _pid, address _recipient) external onlyAdmin onlyPadAdmin(_pid)`

Pad admin use this function to withdraw raised token from the raised token vault of a specific pad.

### setIsWhitelist

> `function setIsWhitelist(uint256 _pid, bool _isWhitelist) public onlyAdmin onlyPadAdmin(_pid)`

Pad admin use this function to set `isWhitelist` of a specific pad.

### setWhitelist

> `function setWhitelist(uint256 _pid, address[] memory _list, bool _status) public onlyAdmin onlyPadAdmin(_pid)`

Pad admin use this function to add users to the whitelist of a specific pad.

## MODIFIER

```solidity
modifier onlyOwner()
modifier onlyAdmin()
modifier onlyPadAdmin(uint256 _pid)
modifier onlyWhilteList(uint256 _pid)
```

## EVENTS

```solidity
event PadAddedBasicInfo(
    IERC20 _saleToken,
    IERC20 _paymentToken,
    IERC20 _stakedToken,
    uint256 _pid, 
    uint256 _salesAmount, 
    uint256 _maxPerUser, 
    uint256 _price, 
    uint256 _minStakedCap, 
    uint256 _maxStakedCap, 
    bool _isWhitelist
);
event PadAddedVaultInfo(
    uint256 _pid,
    SaleTokenVault saleTokenVault,
    RaisedTokenVault raisedTokenVault
);
event PadAddedTimeInfo (
    uint256 _pid,
    uint256 startTime,
    uint256 stakingEndTime,
    uint256 vestingEndTime,
    uint256 cashingEndTime
); 
event WithdrawSaleToken(address indexed sender, address indexed recipient, uint256 amount);
event WithdrawRaisedToken(address indexed sender, address indexed recipient, uint256 amount);
event StakeToGetAlloc(address indexed user, uint256 pid, uint256 amount);
event Claim(address indexed user, uint256 pid, uint256 amount);
event Cash(address indexed user, uint256 pid, uint256 cashedAmount, uint256 paidAmount);
event PadWhitelistSet(uint256 pid, bool isWhitelist);
```
