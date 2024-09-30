# Futureproof Smart Contract System Documentation

## 1. System Overview

The Futureproof smart contract system is designed to provide a secure, flexible, and efficient savings platform on the Base blockchain (Ethereum L2). It incorporates account abstraction (ERC-4337) for improved user experience and implements goal-based savings with interest generation through DeFi protocols.

## 2. Contract Architecture

The system consists of the following main contracts:

1. FutureproofWallet
2. FutureproofFactory
3. InterestGenerator
4. GovernanceContract

### 2.1 Contract Relationships

graph TD
A[FutureproofFactory] -->|creates| B[FutureproofWallet]
B -->|interacts with| C[InterestGenerator]
D[GovernanceContract] -->|manages| A
D -->|manages| C

## 3. Contract Specifications

### 3.1 FutureproofWallet

The core contract for each user, implementing account abstraction and managing individual savings.

#### Key Features:

- Account abstraction (ERC-4337 compliant)
- Multi-token balance management
- Goal-based savings
- Deposit and withdrawal functionality

#### Main Functions:

- `deposit(address token, uint256 amount)`
- `withdraw(address token, uint256 amount)`
- `createSavingsGoal(string name, uint256 targetAmount, uint256 deadline)`
- `allocateToGoal(bytes32 goalId, address token, uint256 amount)`
- `validateUserOp(UserOperation userOp, bytes32 userOpHash, uint256 missingAccountFunds)`

### 3.2 FutureproofFactory

Responsible for creating and managing FutureproofWallet instances.

#### Key Features:

- Wallet creation
- User registry management

#### Main Functions:

- `createWallet(address owner)`
- `getWalletAddress(address owner)`

### 3.3 InterestGenerator

Manages interactions with DeFi protocols and handles interest calculations and distribution.

#### Key Features:

- DeFi protocol integration
- Interest rate calculation
- Interest distribution to user wallets

#### Main Functions:

- `depositToProtocol(address token, uint256 amount)`
- `withdrawFromProtocol(address token, uint256 amount)`
- `calculateInterest(address wallet)`
- `distributeInterest()`

### 3.4 GovernanceContract

Manages system-wide parameters and handles contract upgrades.

#### Key Features:

- Protocol parameter management
- Contract upgrade functionality

#### Main Functions:

- `setInterestRate(uint256 newRate)`
- `setFees(uint256 newDepositFee, uint256 newWithdrawalFee)`
- `upgradeContract(address contractAddress, address newImplementation)`

## 4. Token Management

The system supports multiple tokens:

- USDC
- USDT
- EURC
- cbBTC

Each token is represented by its contract address and managed within the FutureproofWallet contract.

## 5. Account Abstraction (ERC-4337)

Account abstraction is implemented using the EntryPoint contract as specified in ERC-4337. This allows for:

- Gasless transactions
- Batched operations
- Improved UX with social recovery options

## 6. Interest Generation Process

1. User funds are deposited into their FutureproofWallet
2. The InterestGenerator contract aggregates funds across all wallets
3. Aggregated funds are deposited into selected DeFi protocols
4. Interest is accrued within the DeFi protocols
5. The InterestGenerator calculates individual user interest based on their contribution
6. Interest is distributed to user wallets periodically

## 7. Security Measures

- Access Control: OpenZeppelin's `AccessControl` for role-based permissions
- Reentrancy Protection: OpenZeppelin's `ReentrancyGuard`
- Pausability: Ability to pause contracts in case of emergencies
- Time Locks: For large withdrawals and critical operations
- Formal Verification: Of critical functions
- External Audits: Regular security audits by reputable firms

## 8. Upgradeability

The system uses the OpenZeppelin Upgrades plugin with a proxy pattern to allow for future improvements without losing user data.

## 9. Events and Indexing

Detailed events are emitted for all significant actions, designed to be easily indexed by The Graph for efficient querying.

## 10. Gas Optimization

- Efficient storage usage
- Batched operations where possible
- Gas-optimized loops and calculations

## 11. Deployment Process

1. Local development and testing using Hardhat
2. Deployment to Base testnet for integration testing
3. Security audit and addressing of findings
4. Phased deployment to Base mainnet:
   a. Deploy FutureproofFactory
   b. Deploy InterestGenerator
   c. Deploy GovernanceContract
   d. Set up initial protocol parameters
   e. Begin allowing user wallet creation

## 12. Testing Strategy

- Unit Tests: For individual contract functions
- Integration Tests: For inter-contract interactions
- Fuzz Testing: To identify edge cases and vulnerabilities
- Mainnet Forking: To test interactions with existing DeFi protocols

## 13. Monitoring and Maintenance

- Real-time monitoring of contract interactions and balances
- Regular review of gas costs and optimization opportunities
- Continuous integration with automated test runs on each code change
- Scheduled security reviews and audits

## 14. Regulatory Compliance

- Implementation of necessary KYC/AML checks in coordination with the backend system
- Compliance with Nigerian financial regulations
- Regular reporting and audit trails for regulatory requirements
