// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./interfaces/IERC20.sol";
import "./libs/Ownable.sol";
import "./libs/SafeERC20.sol";

contract RaisedTokenVault is Ownable {
    using SafeERC20 for IERC20;
    IERC20 public rasiedToken;

    constructor(address _rasiedToken, address _adminAddress) public {
        rasiedToken = IERC20(_rasiedToken);
        _admin[_adminAddress] = true;
    }

    function withdrawTo(address _to) external onlyOwner {
        rasiedToken.safeTransfer(_to, rasiedToken.balanceOf(address(this)));
    }

    function emergencyWithdraw() external onlyAdmin {
        rasiedToken.safeTransfer(msg.sender, rasiedToken.balanceOf(address(this)));
    }
}