// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./interfaces/IERC20.sol";
import "./libs/Ownable.sol";
import "./libs/SafeERC20.sol";

contract SaleTokenVault is Ownable {
    using SafeERC20 for IERC20;
    IERC20 public saleToken;

    constructor(address _saleToken, address _adminAddress) public {
        saleToken = IERC20(_saleToken);
        _admin[_adminAddress] = true;
    }

    function withdrawRemaining(address _to) external onlyOwner {
        saleToken.safeTransfer(_to, saleToken.balanceOf(address(this)));
    }

    function withdrawTo(address _to, uint256 _amount) external onlyOwner {
        saleToken.safeTransfer(_to, _amount);
    }

    function emergencyWithdraw() external onlyAdmin {
        saleToken.safeTransfer(msg.sender, saleToken.balanceOf(address(this)));
    }
}