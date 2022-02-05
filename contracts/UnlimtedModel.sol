// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./interfaces/IERC20.sol";
import "./libs/Ownable.sol";
import "./libs/SafeERC20.sol";
import "./SaleTokenVault.sol";
import "./RaisedTokenVault.sol";

contract UnlimitedModel is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

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
        // Relative to USD
        uint256 price;
        // The min staked user amount requirement for token sale
        uint256 minStakedUserAmount;
        // The min stake amount requirement for token sale
        uint256 minStakedCap;
        // The max stake amount for token sale(aka soft cap for unlimted sale)
        uint256 maxStakedCap;
        // If this pad require whitelist
        bool isWhitelist;
    }

    struct UserInfo{
        uint256 stakeAmount;
        uint256 allocation;
    }

    PadInfo[] public padInfo;
    mapping(address => bool) public isExistedSaleToken;
    mapping(address => uint256[]) public pidsOfSaleToken;
    mapping(uint256 => address) public padAdmin;
    // user info corresponding specific pad id
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // whitelist info corresponding specifc pad id
    mapping(uint256 => mapping(address => bool)) public whitelist;
    mapping(uint256 => PadTime) private padTime;
    mapping(uint256 => PadVault) private padVault;
    mapping(uint256 => uint256) public padSaleTokenDecimals;
    mapping(uint256 => uint256) public padPaymentTokenDecimals;
    mapping(uint256 => uint256) public multiplierFeeRate;
    address public feeRecipient;
    uint256 constant public PRICE_DECIMALS = 1e18;

    constructor() public {
        /**
        * Set default fee rate list
        * > 0x => 1%(100/10000)
        * > 50x => 0.5%(50/10000)
        * > 100x => 0.3%(30/10000)
        * > 250x => 0.25%(25/10000)
        * > 500x => 0.2%(20/10000)
        * > 1000x => 0.1%(10/10000)
        * > 1500x => 0.05%(5/10000)
        */
        _setMultiplierFeeRate(0, 100);
        _setMultiplierFeeRate(50, 50);
        _setMultiplierFeeRate(100, 30);
        _setMultiplierFeeRate(250, 25);
        _setMultiplierFeeRate(500, 20);
        _setMultiplierFeeRate(1000, 10);
        _setMultiplierFeeRate(1500, 5);
        feeRecipient = msg.sender;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 _pid, uint256 _amount) public onlyWhilteList(_pid) {
        PadInfo storage pad = padInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(padTime[_pid].startTime < block.timestamp, "pad not opened");
        require(padTime[_pid].stakingEndTime > block.timestamp, "staking period ended");
        require(_amount > 0, "invalid amount");
        if (user.stakeAmount == 0) {
            pad.stakedUserAmount += 1;
        }
        user.stakeAmount = user.stakeAmount.add(_amount);
        pad.stakedAmount = pad.stakedAmount.add(_amount);
        pad.stakedToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit StakeToGetAlloc(msg.sender, _pid, _amount);
    }

    // Users can claim back staked token during staking period, or failed after staking period, or after cashing end time
    function claim(uint256 _pid, uint256 _amount) public {
        PadInfo storage pad = padInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.stakeAmount >= _amount, "wrong amount");
        // during staking period
        if (block.timestamp < padTime[_pid].stakingEndTime) {
            user.stakeAmount = user.stakeAmount.sub(_amount);
            // only need to sub pad.stakedAmount and pad.stakedUserAmount during staking period
            pad.stakedAmount = pad.stakedAmount.sub(_amount);
            if (user.stakeAmount == 0) {
                pad.stakedUserAmount -= 1;
            }
            pad.stakedToken.safeTransfer(msg.sender, _amount);
            emit Claim(msg.sender, _pid, _amount);
            return;
        } else if (block.timestamp > padTime[_pid].stakingEndTime && padStatus(_pid) == PadStatus.Fail) {
            // pad failed after staking period
            user.stakeAmount = user.stakeAmount.sub(_amount);
            pad.stakedToken.safeTransfer(msg.sender, _amount);
            emit Claim(msg.sender, _pid, _amount);
            return;
        }
        require(padTime[_pid].cashingEndTime < block.timestamp, "wait for cashing ended");
        user.stakeAmount = user.stakeAmount.sub(_amount);
        pad.stakedToken.safeTransfer(msg.sender, _amount);
        emit Claim(msg.sender, _pid, _amount);
    }

    function cash(uint256 _pid) public {
        PadInfo storage pad = padInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(padTime[_pid].stakingEndTime < block.timestamp, "staking period");
        require(padTime[_pid].vestingEndTime < block.timestamp, "vesting period");
        require(padTime[_pid].cashingEndTime > block.timestamp, "cashing ended");
        require(padStatus(_pid) == PadStatus.Success, "pad failed");
        user.allocation = calcAllocation(_pid);
        require(user.allocation > 0, "not enough allocation to cash");
        pad.cashedAmount = pad.cashedAmount.add(user.allocation);
        uint256 funds = 0;
        if (address(pad.paymentToken) != address(0)) {
            uint256 multiplier = pad.stakedAmount.div(pad.maxStakedCap);
            uint256 feeRate = multiplierFeeRate[0];
            if (multiplier > 50) {
                feeRate = multiplierFeeRate[50];
            } else if (multiplier > 100) {
                feeRate = multiplierFeeRate[100];
            } else if (multiplier > 250) {
                feeRate = multiplierFeeRate[250];
            } else if (multiplier > 500) {
                feeRate = multiplierFeeRate[500];
            } else if (multiplier > 1000) {
                feeRate = multiplierFeeRate[1000];
            } else if (multiplier > 1500) {
                feeRate = multiplierFeeRate[1500];
            }
            funds = user.allocation
                    .mul(pad.price)
                    .mul(padPaymentTokenDecimals[_pid])
                    .div(PRICE_DECIMALS)
                    .div(padSaleTokenDecimals[_pid]);
            uint256 fees = funds.mul(feeRate).div(10000);
            pad.paymentToken.safeTransferFrom(msg.sender, feeRecipient, fees);
            pad.paymentToken.safeTransferFrom(
                msg.sender, 
                address(padVault[_pid].raisedTokenVault), 
                funds
            );
            pad.raisedAmount = pad.raisedAmount.add(funds);
        }
        padVault[_pid].saleTokenVault.withdrawTo(msg.sender, user.allocation);
        emit Cash(msg.sender, _pid, user.allocation, funds);
        pad.stakedToken.safeTransfer(msg.sender, user.stakeAmount);
        emit Claim(msg.sender, _pid, user.stakeAmount);
        user.stakeAmount = 0;
        user.allocation = 0;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function padLength() public view returns (uint256) {
        return padInfo.length;
    }

    function calcAllocation(uint256 _pid) public view returns (uint256) {
        PadInfo storage pad = padInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        return pad.stakedAmount > 0 ? user.stakeAmount.mul(pad.salesAmount).div(pad.stakedAmount) : 0;
    }

    function padPeriod(uint256 _pid) public view returns (PadPeriod) {
        require(padTime[_pid].startTime > 0, "invalid pid");
        if (block.timestamp < padTime[_pid].startTime) {
            return PadPeriod.Prepare;
        } else if (block.timestamp < padTime[_pid].stakingEndTime) {
            return PadPeriod.Staking;
        } else if (block.timestamp < padTime[_pid].vestingEndTime) {
            return PadPeriod.Vesting;
        } else if (block.timestamp < padTime[_pid].cashingEndTime) {
            return PadPeriod.Cashing;
        }
        return PadPeriod.Ended;
    }

    function padStatus(uint256 _pid) public view returns (PadStatus) {
        PadInfo storage pad = padInfo[_pid];
        if (pad.stakedAmount >= pad.minStakedCap && pad.stakedUserAmount >= pad.minStakedUserAmount) {
            return PadStatus.Success;
        } 
        return PadStatus.Fail;
    }

    function getPadTime(uint256 _pid) 
        public 
        view 
        returns (
            uint256 startTime, 
            uint256 stakingEndTime, 
            uint256 vestingEndTime, 
            uint256 cashingEndTime
        ) 
    {
        startTime = padTime[_pid].startTime;
        stakingEndTime = padTime[_pid].stakingEndTime;
        vestingEndTime = padTime[_pid].vestingEndTime;
        cashingEndTime = padTime[_pid].cashingEndTime;
    }

    function getPadVault(uint256 _pid)
        public 
        view 
        returns (
            address saleTokenVault, 
            address raisedTokenVault
        ) 
    {
        saleTokenVault = address(padVault[_pid].saleTokenVault);
        raisedTokenVault = address(padVault[_pid].raisedTokenVault);
    }

    function getPids(address _saleToken) public view returns (uint256[] memory) {
        return pidsOfSaleToken[_saleToken];
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _setMultiplierFeeRate(uint256 _multiplier, uint256 _feeRate) internal {
        multiplierFeeRate[_multiplier] = _feeRate;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**
     * tokens array represents sale token, payment token and staked token order by index
     * time array represents start time, staking period, vesting period and cashing period order by index
     * _decimals array represents sale token and payment token decimals order by index
     */
     function addPad(
        address[] memory tokens,
        address _adminAddress,
        uint256[] memory time,
        uint256[] memory _decimals,
        uint256 _salesAmount,
        uint256 _price,
        uint256 _minStakedUserAmount,
        uint256 _minStakedCap,
        uint256 _maxStakedCap,
        bool _isWhitelist
    ) public onlyOwner {
        require(time[0] > block.timestamp, "invalid start time");
        require(time[1] > 0 && time[2] > 0 && time[3] > 0, "invalid period founded");

        padInfo.push(
            PadInfo({
                saleToken: IERC20(tokens[0]),
                paymentToken: IERC20(tokens[1]),
                stakedToken: IERC20(tokens[2]),
                salesAmount: _salesAmount,
                stakedAmount: 0,
                stakedUserAmount: 0,
                cashedAmount: 0,
                raisedAmount: 0,
                price: _price,
                minStakedUserAmount: _minStakedUserAmount,
                minStakedCap: _minStakedCap,
                maxStakedCap: _maxStakedCap,
                isWhitelist: _isWhitelist
            })
        );
        uint256 pid = padInfo.length - 1;
        emit PadAddedBasicInfo(
            IERC20(tokens[0]),
            IERC20(tokens[1]),
            IERC20(tokens[2]),
            pid,
            _salesAmount,
            _price,
            _minStakedUserAmount,
            _minStakedCap,
            _maxStakedCap,
            _isWhitelist
        );

        padSaleTokenDecimals[pid] = _decimals[0];
        padPaymentTokenDecimals[pid] = _decimals[1];

        padVault[pid].saleTokenVault = new SaleTokenVault(tokens[0], msg.sender);
        padVault[pid].raisedTokenVault = new RaisedTokenVault(tokens[1], msg.sender);
        emit PadAddedVaultInfo(
            pid,
            padVault[pid].saleTokenVault,
            padVault[pid].raisedTokenVault
        );

        padTime[pid].startTime = time[0];
        padTime[pid].stakingEndTime = time[0].add(time[1]);
        padTime[pid].vestingEndTime = padTime[pid].stakingEndTime.add(time[2]);
        padTime[pid].cashingEndTime = padTime[pid].vestingEndTime.add(time[3]);
        emit PadAddedTimeInfo(
            pid,
            time[0],
            padTime[pid].stakingEndTime,
            padTime[pid].vestingEndTime,
            padTime[pid].cashingEndTime
        );

        isExistedSaleToken[tokens[0]] = true;
        padAdmin[pid] = _adminAddress;
        pidsOfSaleToken[tokens[0]].push(pid);
    }

    function depositSaleToken(uint256 _pid) external onlyAdmin onlyPadAdmin(_pid) {
        PadInfo storage pad = padInfo[_pid];
        pad.saleToken.safeTransferFrom(msg.sender, address(padVault[_pid].saleTokenVault), pad.salesAmount);
    }

    function withdrawRemainingSaleToken(uint256 _pid, address _recipient) external onlyAdmin onlyPadAdmin(_pid) {
        PadInfo storage pad = padInfo[_pid];
        require(padTime[_pid].cashingEndTime < block.timestamp, "not ended");
        padVault[_pid].saleTokenVault.withdrawRemaining(_recipient);
        emit WithdrawSaleToken(msg.sender, _recipient, pad.saleToken.balanceOf(address(padVault[_pid].saleTokenVault)));
    } 

    function withdrawRaisedToken(uint256 _pid, address _recipient) external onlyAdmin onlyPadAdmin(_pid) {
        PadInfo storage pad = padInfo[_pid];
        require(padTime[_pid].cashingEndTime < block.timestamp, "not ended");
        padVault[_pid].raisedTokenVault.withdrawTo(_recipient);
        emit WithdrawRaisedToken(msg.sender, _recipient, pad.paymentToken.balanceOf(address(padVault[_pid].raisedTokenVault)));
    }

    function setIsWhitelist(uint256 _pid, bool _isWhitelist) public onlyAdmin onlyPadAdmin(_pid) {
        PadInfo storage pad = padInfo[_pid];
        pad.isWhitelist = _isWhitelist;
        emit PadWhitelistSet(_pid, _isWhitelist);
    }

    function setWhitelist(uint256 _pid, address[] memory _list, bool _status) public onlyAdmin onlyPadAdmin(_pid) {
        for(uint i = 0;i < _list.length; i++){
            whitelist[_pid][_list[i]] = _status;
        }
    }

    function setMultiplierFeeRate(uint256 _multiplier, uint256 _feeRate) external onlyOwner {
        _setMultiplierFeeRate(_multiplier, _feeRate);
        emit MulitplierFeeRateSet(msg.sender, _multiplier, _feeRate);
    }

    function setFeeRecipient(address _newRecipient) external onlyOwner {
        feeRecipient = _newRecipient;
    }

    /* ========== MODIFIER ========== */

    modifier onlyPadAdmin(uint256 _pid) {
        require(msg.sender == padAdmin[_pid], "wrong admin for this pad");
        _;
    }

    modifier onlyWhilteList(uint256 _pid){
        PadInfo storage pad = padInfo[_pid];
        if(pad.isWhitelist){
            require(whitelist[_pid][msg.sender],"Not whitelisted");
        }
        _;
    }

    /* ========== EVENTS ========== */
    event PadAddedBasicInfo(
        IERC20 _saleToken,
        IERC20 _paymentToken,
        IERC20 _stakedToken,
        uint256 _pid, 
        uint256 _salesAmount, 
        uint256 _price, 
        uint256 _minStakedUserAmount, 
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
    event MulitplierFeeRateSet(address indexed setter, uint256 multiplier, uint256 feeRate);
}