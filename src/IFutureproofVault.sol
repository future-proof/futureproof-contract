// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IFutureproofVault {
    struct UserBalance {
        uint256 balance;
        uint256 lastInterestUpdate;
    }

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event BalanceRootUpdated(bytes32 newRoot);
    event TokenAdded(address indexed token, address indexed aToken);
    event TokenRemoved(address indexed token);
    event InterestClaimed(address indexed token, uint256 amount);
    event InterestDistributed(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    error UnsupportedToken(address token);
    error InvalidProof();
    error InsufficientBalance(uint256 requested, uint256 available);

    function aavePool() external view returns (address);
    function supportedTokens(address token) external view returns (bool);
    function aTokens(address token) external view returns (address);
    function balanceRoot() external view returns (bytes32);
    function allUsers(uint256 index) external view returns (address);

    function deposit(address token, uint256 amount) external;
    function withdrawWithProof(
        address token,
        uint256 amount,
        bytes32[] calldata proof
    ) external;
    function claimAndDistributeInterest(address token) external;
    function addSupportedToken(address token, address aToken) external;
    function removeSupportedToken(address token) external;
    function updateBalanceRoot(bytes32 newRoot) external;
    function getUserBalance(
        address user,
        address token
    ) external view returns (uint256);
    function pause() external;
    function unpause() external;
    function rescueTokens(address token, uint256 amount) external;
}
