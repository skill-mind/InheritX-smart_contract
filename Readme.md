# Contributing to InheritX Smart Contract

Thank you for your interest in contributing to InheritX! **InheritX** is a revolutionary blockchain-powered digital asset inheritance platform that empowers users to securely manage, transfer, and optimize their digital assets—including cryptocurrencies and NFTs—using a decentralized exchange (DEX) swap feature. Built on StarkNet, InheritX ensures transparency, security, and automation in digital estate planning.

## Project Overview

**InheritX** combines:
- **Digital Asset Inheritance:** Secure, automated transfer of digital assets to designated beneficiaries.
- **DEX Swap Integration**: Pre- and post-inheritance asset swaps for optimal portfolio management.
- **Blockchain Technology:** Leveraging **StarkNet** to guarantee a decentralized, trustless, and secure environment.
- **User-Centric Design:** Intuitive dashboards and robust identity verification for asset owners and beneficiaries.

# How to Apply 
1. Star the project
2. Drop your TG handle
3. Join the group `https://t.me/+xN161b3GkwNiYTZk`


## How to Contribute

We welcome contributions in various forms, including bug fixes, feature implementations, and documentation improvements.

### 1. Fork the Repository
1. Navigate to the 
(https://github.com/skill-mind/InheritX-smart_contract.git).
2. Click the **Fork** button to create your copy of the repository.

### 2. Clone the Repository
- Clone your forked repository to your local machine:
```bash
git clone https://github.com/<your-username>/InheritX-smart_contract.git
cd InheritX-smart_contract
```


### 3. Create a New Branch

**Create a branch for your feature or bug fix:**
```bash
  git checkout -b feature/<Issue title>
```

### 5. Make Changes and Commit

- Implement your changes.
- Test your changes thoroughly.
- Commit your work with a descriptive message:

```bash
   git add .
   git commit -m "Issue Title"
```

### 6. Push Changes
 - Push your branch to your forked repository:

```bash
   git push origin <Issue Title>
```

### 7. Create a Pull Request (PR)

- Click on Pull Requests and select New Pull Request.
- Provide a clear and concise title and description for your PR.
- Link any relevant issues.

**Code of Conduct**

- Please adhere to our Code of Conduct to maintain a respectful and inclusive community.

### Contribution Guidelines
- Write clean and modular code following the repository's coding standards.
- Ensure all changes are tested before submission.
- Document new features and updates thoroughly.

# Upgradeable Contract System Deployment Guide

This document provides instructions for deploying and upgrading the counter contract system using Starknet.

## Prerequisites

- Starknet CLI installed
- Cairo compiler installed
- Account configured with Starknet

## Deployment Steps

### 1. Compile the Contracts

First, compile all the contracts:

```bash
scarb build
```

### 2. Declare Logic Contract (V1)

```bash
starknet declare --contract target/release/CounterLogic.json
```

Make note of the returned class hash: `0x<LOGIC_CLASS_HASH>`

### 3. Deploy Logic Contract (V1)

```bash
starknet deploy --class_hash 0x<LOGIC_CLASS_HASH> --inputs <OWNER_ADDRESS>
```

### 4. Declare Proxy Contract

```bash
starknet declare --contract target/release/CounterProxy.json
```

Make note of the returned class hash: `0x<PROXY_CLASS_HASH>`

### 5. Deploy Proxy Contract

```bash
starknet deploy --class_hash 0x<PROXY_CLASS_HASH> --inputs <OWNER_ADDRESS> <LOGIC_CLASS_HASH>
```

Your proxy contract is now deployed with the class hash of the logic contract. The proxy contract will be the one users interact with.

## Upgrading the Contract

When you want to upgrade to a new version of the logic contract, follow these steps:

### 1. Declare New Logic Contract (V2)

```bash
starknet declare --contract target/release/CounterLogicV2.json
```

Make note of the returned class hash: `0x<LOGIC_V2_CLASS_HASH>`

### 2. Call the Upgrade Function on Proxy

```bash
starknet invoke \
  --address <PROXY_CONTRACT_ADDRESS> \
  --function upgrade \
  --inputs <LOGIC_V2_CLASS_HASH> \
  --account <YOUR_ACCOUNT>
```

### 3. Verify the Upgrade

You can verify that the logic contract has been upgraded by calling the `get_version` function:

```bash
starknet call \
  --address <PROXY_CONTRACT_ADDRESS> \
  --function get_version
```

The response should be "v2.0", confirming that the upgrade was successful.

## State Persistence

The beauty of this upgrade pattern is that all state is stored in the proxy contract. When you upgrade the logic contract, the state remains intact in the proxy contract's storage. This means:

1. Counter values will persist after an upgrade
2. Ownership will remain the same
3. Any other state variables will be preserved

## Security Considerations

1. Only the contract owner can perform an upgrade
2. The proxy pattern ensures that state is preserved during upgrades
3. New implementations can add functionality but shouldn't change the storage layout

## Community Engagement

Join our Telegram group to discuss this project and share your feedback:
[TG Group Link] (replace with your actual TG group link)

When you join, please drop your TG handle so we can welcome you properly!

## Troubleshooting

If you encounter any issues during deployment or upgrade, please:

1. Verify that you're using the correct class hashes
2. Make sure you're calling functions with the correct account (owner)
3. Check transaction receipts for detailed error messages

## STARK Proof Integration (Planned)

### Overview
Starknet's STARK proofs will enable scalable, off-chain verification for complex checks (e.g., inactivity periods). While direct on-chain STARK proof verification is not yet available, InheritX is architected for future integration.

### Current Implementation
- A placeholder function `verify_claim_with_proof` is implemented in the contract and interface.
- This function hashes claim data using Poseidon and accepts a proof parameter.
- Currently, the function mocks verification and always returns `true`.
- Claim data is formatted and hashed for future compatibility with STARK proof verification.

### Roadmap & Next Steps
- Monitor Starknet's roadmap for native STARK proof verification support.
- Once available, update `verify_claim_with_proof` to perform actual proof verification.
- Unit tests are in place to validate the placeholder logic and will be updated for real proofs.

### Developer Notes
- See `src/InheritX.cairo` and `src/interfaces/IInheritX.cairo` for the placeholder implementation.
- See `tests/test_inheritx.cairo` for unit tests mocking proof verification.
- This approach ensures the contract is future-proof and ready for scalable, off-chain verification as soon as Starknet supports it.

Thank you for contributing to InheritX and helping us build a secure, innovative platform for digital asset inheritance!
