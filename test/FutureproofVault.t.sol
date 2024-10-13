// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FutureproofVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MockAavePool is IPool {
    mapping(address => uint256) private _deposits;

    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external override {
        _deposits[onBehalfOf] += amount;
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external override returns (uint256) {
        require(_deposits[msg.sender] >= amount, "Insufficient balance");
        _deposits[msg.sender] -= amount;
        IERC20(asset).transfer(to, amount);
        return amount;
    }

    // Implement other required functions with dummy returns
    function mintUnbacked(
        address,
        uint256,
        address,
        uint16
    ) external override {}
    function backUnbacked(
        address,
        uint256,
        uint256
    ) external override returns (uint256) {
        return 0;
    }
    function setUserUseReserveAsCollateral(address, bool) external override {}
    function liquidationCall(
        address,
        address,
        address,
        uint256,
        bool
    ) external override {}
    function flashLoan(
        address,
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        address,
        bytes calldata,
        uint16
    ) external override {}
    function flashLoanSimple(
        address,
        address,
        uint256,
        bytes calldata,
        uint16
    ) external override {}
    function getUserAccountData(
        address
    )
        external
        view
        override
        returns (uint256, uint256, uint256, uint256, uint256, uint256)
    {
        return (0, 0, 0, 0, 0, 0);
    }
    function initReserve(
        address,
        address,
        address,
        address,
        address
    ) external override {}
    function dropReserve(address) external override {}
    function setReserveInterestRateStrategyAddress(
        address,
        address
    ) external override {}
    function setConfiguration(
        address,
        DataTypes.ReserveConfigurationMap calldata
    ) external override {}
    function getConfiguration(
        address
    )
        external
        view
        override
        returns (DataTypes.ReserveConfigurationMap memory)
    {
        return DataTypes.ReserveConfigurationMap(0);
    }
    function getUserConfiguration(
        address
    ) external view override returns (DataTypes.UserConfigurationMap memory) {
        return DataTypes.UserConfigurationMap(0);
    }
    function getReserveNormalizedIncome(
        address
    ) external view override returns (uint256) {
        return 0;
    }
    function getReserveNormalizedVariableDebt(
        address
    ) external view override returns (uint256) {
        return 0;
    }
    function finalizeTransfer(
        address,
        address,
        address,
        uint256,
        uint256,
        uint256
    ) external override {}
    function getReservesList()
        external
        view
        override
        returns (address[] memory)
    {
        return new address[](0);
    }
    function getReserveData(
        address
    ) external view override returns (DataTypes.ReserveData memory) {
        return
            DataTypes.ReserveData(
                DataTypes.ReserveConfigurationMap(0),
                0,
                0,
                0,
                0,
                0,
                0,
                address(0),
                address(0),
                address(0),
                address(0),
                0
            );
    }
    function borrow(
        address,
        uint256,
        uint256,
        uint16,
        address
    ) external override {}
    function repay(
        address,
        uint256,
        uint256,
        address
    ) external override returns (uint256) {
        return 0;
    }
    function swapBorrowRateMode(address, uint256) external override {}
    function rebalanceStableBorrowRate(address, address) external override {}
    function setUserEMode(uint8) external override {}
    function getUserEMode(address) external view override returns (uint256) {
        return 0;
    }
    function resetIsolationModeTotalDebt(address) external override {}
    function rescueTokens(address, address, uint256) external override {}
    function deposit(address, uint256, address, uint16) external override {}
}

contract FutureproofVaultTest is Test {
    FutureproofVault public vault;
    ERC20Mock public token;
    MockAavePool public aavePool;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        aavePool = new MockAavePool();
        vault = new FutureproofVault(address(aavePool));
        token = new ERC20Mock(
            "Test Token",
            "TEST",
            address(this),
            1000000 ether
        );

        // Add token as supported
        vault.addSupportedToken(address(token), address(0)); // Using 0 address as aToken for simplicity

        // Mint some tokens to users
        token.mint(user1, 1000 ether);
        token.mint(user2, 1000 ether);

        // Approve vault to spend tokens
        vm.prank(user1);
        token.approve(address(vault), type(uint256).max);
        vm.prank(user2);
        token.approve(address(vault), type(uint256).max);
    }

    function testDeposit() public {
        vm.prank(user1);
        vault.deposit(address(token), 100 ether);

        assertEq(vault.getUserBalance(user1, address(token)), 100 ether);
        assertEq(token.balanceOf(address(aavePool)), 100 ether);
    }

    function testWithdraw() public {
        vm.prank(user1);
        vault.deposit(address(token), 100 ether);

        // Generate a valid Merkle proof (this is a simplified version)
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(
            abi.encodePacked(user1, address(token), uint256(100 ether))
        );

        vm.prank(user1);
        vault.withdrawWithProof(address(token), 50 ether, proof);

        assertEq(vault.getUserBalance(user1, address(token)), 50 ether);
        assertEq(token.balanceOf(user1), 950 ether);
    }

    function testMultipleUsersDeposit() public {
        vm.prank(user1);
        vault.deposit(address(token), 100 ether);

        vm.prank(user2);
        vault.deposit(address(token), 150 ether);

        assertEq(vault.getUserBalance(user1, address(token)), 100 ether);
        assertEq(vault.getUserBalance(user2, address(token)), 150 ether);
        assertEq(token.balanceOf(address(aavePool)), 250 ether);
    }

    function testFailDepositUnsupportedToken() public {
        ERC20Mock unsupportedToken = new ERC20Mock(
            "Unsupported Token",
            "UNSUP",
            address(this),
            1000 ether
        );
        unsupportedToken.mint(user1, 100 ether);

        vm.prank(user1);
        unsupportedToken.approve(address(vault), type(uint256).max);

        vm.prank(user1);
        vault.deposit(address(unsupportedToken), 100 ether);
    }

    function testFailWithdrawMoreThanBalance() public {
        vm.prank(user1);
        vault.deposit(address(token), 100 ether);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(
            abi.encodePacked(user1, address(token), uint256(100 ether))
        );

        vm.prank(user1);
        vault.withdrawWithProof(address(token), 150 ether, proof);
    }

    function testPauseAndUnpause() public {
        vault.pause();
        assertTrue(vault.paused());

        vm.expectRevert("Pausable: paused");
        vm.prank(user1);
        vault.deposit(address(token), 100 ether);

        vault.unpause();
        assertFalse(vault.paused());

        vm.prank(user1);
        vault.deposit(address(token), 100 ether);
        assertEq(vault.getUserBalance(user1, address(token)), 100 ether);
    }

    function testAddAndRemoveSupportedToken() public {
        ERC20Mock newToken = new ERC20Mock(
            "New Token",
            "NEW",
            address(this),
            1000 ether
        );
        address mockAToken = address(0x123);

        vault.addSupportedToken(address(newToken), mockAToken);
        assertTrue(vault.supportedTokens(address(newToken)));
        assertEq(vault.aTokens(address(newToken)), mockAToken);

        vault.removeSupportedToken(address(newToken));
        assertFalse(vault.supportedTokens(address(newToken)));
        assertEq(vault.aTokens(address(newToken)), address(0));
    }

    function testUpdateBalanceRoot() public {
        bytes32 newRoot = keccak256("new root");
        vault.updateBalanceRoot(newRoot);
        assertEq(vault.balanceRoot(), newRoot);
    }

    function testFailNonOwnerFunctions() public {
        ERC20Mock newToken = new ERC20Mock(
            "New Token",
            "NEW",
            address(this),
            1000 ether
        );

        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.addSupportedToken(address(newToken), address(0));

        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.removeSupportedToken(address(token));

        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.updateBalanceRoot(bytes32(0));

        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.pause();

        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.unpause();
    }

    function testRescueTokens() public {
        // Simulate some tokens stuck in the contract
        token.mint(address(vault), 100 ether);

        uint256 initialBalance = token.balanceOf(owner);
        vault.rescueTokens(address(token), 100 ether);
        uint256 finalBalance = token.balanceOf(owner);

        assertEq(finalBalance - initialBalance, 100 ether);
    }

    function testFailRescueTokensNonOwner() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.rescueTokens(address(token), 100 ether);
    }
}
