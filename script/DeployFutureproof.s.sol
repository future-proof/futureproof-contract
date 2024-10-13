// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/FutureproofVault.sol";
import "@aave/core-v3/contracts/protocol/pool/Pool.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

contract DeployFutureproof is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy a mock PoolAddressesProvider
        MockPoolAddressesProvider mockAddressesProvider = new MockPoolAddressesProvider();

        // Deploy Aave Pool
        Pool aavePool = new Pool(
            IPoolAddressesProvider(address(mockAddressesProvider))
        );
        console.log("Aave Pool deployed at:", address(aavePool));

        // Set the pool address in the mock provider
        mockAddressesProvider.setPool(address(aavePool));

        // Deploy FutureproofVault
        FutureproofVault futureproofVault = new FutureproofVault(
            address(aavePool)
        );
        console.log("FutureproofVault deployed at:", address(futureproofVault));

        vm.stopBroadcast();
    }
}

contract MockPoolAddressesProvider is IPoolAddressesProvider {
    address private _pool;
    string private _marketId;

    function getPool() external view override returns (address) {
        return _pool;
    }

    function setPool(address newPool) external {
        _pool = newPool;
    }

    function getMarketId() external view override returns (string memory) {
        return _marketId;
    }

    function setMarketId(string calldata newMarketId) external override {
        _marketId = newMarketId;
    }

    // Implement other required functions with dummy returns
    function setAddressAsProxy(bytes32, address) external override {}
    function setAddress(bytes32, address) external override {}
    function getAddress(bytes32) external view override returns (address) {
        return address(0);
    }
    function getACLAdmin() external view override returns (address) {
        return address(0);
    }
    function getACLManager() external view override returns (address) {
        return address(0);
    }
    function getPoolConfigurator() external view override returns (address) {
        return address(0);
    }
    function getPoolDataProvider() external view override returns (address) {
        return address(0);
    }
    function getPriceOracle() external view override returns (address) {
        return address(0);
    }
    function getPriceOracleSentinel() external view override returns (address) {
        return address(0);
    }
    function setACLAdmin(address) external override {}
    function setACLManager(address) external override {}
    function setPoolConfiguratorImpl(address) external override {}
    function setPoolDataProvider(address) external override {}
    function setPoolImpl(address) external override {}
    function setPriceOracle(address) external override {}
    function setPriceOracleSentinel(address) external override {}
}
