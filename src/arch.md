graph TD
User[User] -->|Interacts with| FE[Frontend Interface]
FE -->|Deposits/Withdraws| FV[FutureproofVault Contract]
FE -->|Requests Balance/Proof| BE[Backend Service]

    subgraph "On-Chain"
        FV -->|Emits Events| EL[Event Listener]
        FV -->|Verifies Proofs| MP[Merkle Proof Verifier]
        FV -->|Manages| ST[Supported Tokens]
    end

    subgraph "Off-Chain"
        BE -->|Updates| MT[Merkle Tree]
        BE -->|Generates| MP[Merkle Proofs]
        EL -->|Updates| MT
        BE -->|Manages| UB[User Balances]
    end

    subgraph "External Services"
        OR[On-Ramp Service] -->|Initiates Deposit| BE
        BE -->|Triggers| FR[Fiat-to-Crypto Conversion]
        FR -->|Completes| FV

        FV -->|Initiates Withdrawal| OR[Off-Ramp Service]
        OR -->|Triggers| CF[Crypto-to-Fiat Conversion]
        CF -->|Completes| User
    end

    subgraph "Interest Generation"
        IG[Interest Generator] -->|Calculates Interest| BE
        BE -->|Updates| MT
        IG -->|Distributes Interest| FV
    end
