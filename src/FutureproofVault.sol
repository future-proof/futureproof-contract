// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IAToken} from "@aave/core-v3/contracts/interfaces/IAToken.sol";

contract FutureproofVault is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct UserBalance {
        uint256 balance;
        uint256 lastInterestUpdate;
    }

    IPool public aavePool;
    mapping(address => mapping(address => UserBalance)) private userBalances;
    mapping(address => bool) public supportedTokens;
    mapping(address => address) public aTokens;
    bytes32 public balanceRoot;
    address[] public allUsers;
    mapping(address => bool) private isUser;

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

    constructor(address _aavePool) Ownable(msg.sender) {
        aavePool = IPool(_aavePool);
    }

    function deposit(
        address token,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        if (!supportedTokens[token]) revert UnsupportedToken(token);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _updateUserBalance(msg.sender, token, amount, true);

        // Deposit into Aave
        aavePool.supply(token, amount, address(this), 0);

        if (!isUser[msg.sender]) {
            allUsers.push(msg.sender);
            isUser[msg.sender] = true;
        }

        emit Deposit(msg.sender, token, amount);
    }

    function withdrawWithProof(
        address token,
        uint256 amount,
        bytes32[] calldata proof
    ) external nonReentrant whenNotPaused {
        if (!supportedTokens[token]) revert UnsupportedToken(token);
        if (!_verifyProof(msg.sender, token, amount, proof))
            revert InvalidProof();

        UserBalance storage userBalance = userBalances[msg.sender][token];
        uint256 currentBalance = _calculateCurrentBalance(token, userBalance);
        if (amount > currentBalance)
            revert InsufficientBalance(amount, currentBalance);

        _updateUserBalance(msg.sender, token, amount, false);

        // Withdraw from Aave
        aavePool.withdraw(token, amount, address(this));

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdrawal(msg.sender, token, amount);
    }

    function claimAndDistributeInterest(address token) external onlyOwner {
        address aToken = aTokens[token];
        uint256 aTokenBalance = IERC20(aToken).balanceOf(address(this));
        uint256 underlyingBalance = IAToken(aToken).balanceOf(address(this));
        uint256 interest = underlyingBalance - aTokenBalance;

        if (interest > 0) {
            aavePool.withdraw(token, interest, address(this));
            _distributeInterest(token, interest);
            emit InterestClaimed(token, interest);
        }
    }

    function addSupportedToken(
        address token,
        address aToken
    ) external onlyOwner {
        supportedTokens[token] = true;
        aTokens[token] = aToken;

        // Approve Aave Pool to spend max uint256 tokens
        IERC20(token).approve(address(aavePool), type(uint256).max);

        emit TokenAdded(token, aToken);
    }

    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
        delete aTokens[token];
        emit TokenRemoved(token);
    }

    function updateBalanceRoot(bytes32 newRoot) external onlyOwner {
        balanceRoot = newRoot;
        emit BalanceRootUpdated(newRoot);
    }

    function getUserBalance(
        address user,
        address token
    ) external view returns (uint256) {
        return _calculateCurrentBalance(token, userBalances[user][token]);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }

    function _updateUserBalance(
        address user,
        address token,
        uint256 amount,
        bool isDeposit
    ) private {
        UserBalance storage userBalance = userBalances[user][token];
        uint256 currentBalance = _calculateCurrentBalance(token, userBalance);

        if (isDeposit) {
            userBalance.balance = currentBalance + amount;
        } else {
            userBalance.balance = currentBalance - amount;
        }

        userBalance.lastInterestUpdate = block.timestamp;
    }

    function _calculateCurrentBalance(
        address token,
        UserBalance memory userBalance
    ) private view returns (uint256) {
        address aToken = aTokens[token];
        uint256 aTokenBalance = IERC20(aToken).balanceOf(address(this));
        uint256 underlyingBalance = IAToken(aToken).balanceOf(address(this));
        uint256 totalInterest = underlyingBalance > aTokenBalance
            ? underlyingBalance - aTokenBalance
            : 0;

        uint256 userShare = (userBalance.balance * 1e18) / aTokenBalance;
        uint256 userInterest = (totalInterest * userShare) / 1e18;

        return userBalance.balance + userInterest;
    }

    function _distributeInterest(
        address token,
        uint256 interestAmount
    ) private {
        uint256 totalBalance = IERC20(aTokens[token]).totalSupply();
        if (totalBalance == 0) return; // No users to distribute interest to

        address[] memory users = _getUsersForToken(token);
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            UserBalance storage userBalance = userBalances[user][token];
            uint256 userShare = (userBalance.balance * 1e18) / totalBalance;
            uint256 userInterest = (interestAmount * userShare) / 1e18;
            userBalance.balance += userInterest;
            emit InterestDistributed(user, token, userInterest);
        }
    }

    function _getUsersForToken(
        address token
    ) private view returns (address[] memory) {
        uint256 userCount = 0;
        for (uint256 i = 0; i < allUsers.length; i++) {
            if (userBalances[allUsers[i]][token].balance > 0) {
                userCount++;
            }
        }

        address[] memory usersWithBalance = new address[](userCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allUsers.length; i++) {
            if (userBalances[allUsers[i]][token].balance > 0) {
                usersWithBalance[index] = allUsers[i];
                index++;
            }
        }

        return usersWithBalance;
    }

    function _verifyProof(
        address user,
        address token,
        uint256 amount,
        bytes32[] memory proof
    ) private view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user, token, amount));
        return MerkleProof.verify(proof, balanceRoot, leaf);
    }
}
