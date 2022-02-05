// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./interfaces/IERC20.sol";
import "./libs/Ownable.sol";
import "./libs/SafeERC20.sol";
import "./SaleTokenVault.sol";
import "./RaisedTokenVault.sol";

contract BasicModel is Ownable {
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
    uint256 constant public PRICE_DECIMALS = 1e18;

    constructor() public {}

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 _pid, uint256 _amount) public onlyWhilteList(_pid) {
        PadInfo storage pad = padInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(padTime[_pid].startTime < block.timestamp, "pad not opened");
        require(padTime[_pid].stakingEndTime > block.timestamp, "staking period ended");
        require(_amount > 0, "invalid amount");
        require(pad.stakedAmount + _amount <= pad.maxStakedCap, "exceeds max total staked amount");
        require(user.stakeAmount + _amount <= pad.maxPerUser, "exceeds max staked amount per user");
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
        require(pad.stakedAmount >= pad.minStakedCap, "min cap not reached");
        user.allocation = calcAllocation(_pid);
        require(user.allocation > 0, "not enough allocation to cash");
        pad.cashedAmount = pad.cashedAmount.add(user.allocation);
        uint256 funds = 0;
        if (address(pad.paymentToken) != address(0)) {
            funds = user.allocation
                    .mul(pad.price)
                    .mul(padPaymentTokenDecimals[_pid])
                    .div(padSaleTokenDecimals[_pid])
                    .div(PRICE_DECIMALS);
            pad.paymentToken.safeTransferFrom(msg.sender, address(padVault[_pid].raisedTokenVault), funds);
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
        if (pad.stakedAmount >= pad.minStakedCap) {
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
        uint256 _maxPerUser,
        uint256 _price,
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
                maxPerUser: _maxPerUser,
                price: _price,
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
            _maxPerUser,
            _price,
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
}
