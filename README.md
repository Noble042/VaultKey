# VaultKey Smart Contract

VaultKey is a decentralized time-locked vault system implemented in Clarity for the Stacks blockchain. It enables users to create secure, time-locked vaults for tokens and NFTs with multi-signature release mechanisms and emergency unlock capabilities.

## Features

### Core Functionality
- Create time-locked vaults for tokens
- Create time-locked vaults for NFTs
- Multi-signature release mechanism
- Emergency unlock system with arbitration
- Customizable unlock heights
- Flexible signer requirements

### Security Features
- Input validation for all operations
- Multi-signature verification
- Time-lock enforcement
- Owner and signer authorization checks
- Emergency unlock controls
- Secure vault management

## Contract Methods

### Vault Creation
```clarity
(create-token-vault (unlock-height uint) (token-amount uint) (required-sigs uint) (signers (list 5 principal)))
(create-nft-vault (unlock-height uint) (nft-id uint) (required-sigs uint) (signers (list 5 principal)))
```
Creates new vaults for tokens or NFTs with specified parameters.

### Vault Management
```clarity
(sign-vault-withdrawal (vault-id uint))
(withdraw-from-vault (vault-id uint))
(initiate-emergency-unlock (vault-id uint))
```
Functions for managing vault signatures, withdrawals, and emergency procedures.

### Administrative
```clarity
(set-arbitrator (new-arbitrator principal))
```
Sets the contract arbitrator who can initiate emergency unlocks.

### Read-Only Functions
```clarity
(get-vault-details (vault-id uint))
(get-signature-count (vault-id uint))
(is-vault-unlocked (vault-id uint))
```
Query vault information and status.

## Error Codes

| Code | Description |
|------|-------------|
| ERR-NOT-AUTHORIZED (u1) | User not authorized for operation |
| ERR-VAULT-NOT-FOUND (u2) | Specified vault doesn't exist |
| ERR-VAULT-LOCKED (u3) | Vault is still time-locked |
| ERR-INVALID-UNLOCK-HEIGHT (u4) | Invalid unlock height specified |
| ERR-ZERO-AMOUNT (u5) | Token amount must be greater than zero |
| ERR-INVALID-SIGNERS (u6) | Invalid signer configuration |
| ERR-ALREADY-SIGNED (u7) | Signer has already signed |
| ERR-INSUFFICIENT-SIGNATURES (u8) | Not enough signatures for withdrawal |
| ERR-NOT-ARBITRATOR (u9) | Caller is not the arbitrator |
| ERR-EMERGENCY-NOT-ACTIVE (u10) | Emergency unlock not activated |
| ERR-INVALID-NFT (u11) | Invalid NFT ID specified |
| ERR-INVALID-VAULT (u12) | Invalid vault ID specified |

## Usage Examples

### Creating a Token Vault
```clarity
;; Create a vault requiring 3 signatures, unlocking at block height 10000
(create-token-vault u10000 u1000 u3 (list tx-sender principal-2 principal-3 principal-4 principal-5))
```

### Creating an NFT Vault
```clarity
;; Create a vault for NFT #123 requiring 2 signatures
(create-nft-vault u10000 u123 u2 (list tx-sender principal-2 principal-3 principal-4 principal-5))
```

### Signing and Withdrawing
```clarity
;; Sign a vault withdrawal
(sign-vault-withdrawal u1)

;; Withdraw from vault (must have required signatures and be unlocked)
(withdraw-from-vault u1)
```

### Emergency Procedures
```clarity
;; Initiate emergency unlock (arbitrator only)
(initiate-emergency-unlock u1)
```

## Security Considerations

1. Always verify vault IDs before operations
2. Ensure sufficient signatures before withdrawal
3. Check time-lock periods carefully
4. Verify emergency unlock procedures
5. Monitor signature counts and requirements
6. Validate all inputs thoroughly

## Development Setup

1. Install Clarinet for local development
2. Clone the repository
3. Run tests using Clarinet
```bash
clarinet check
clarinet test
```

## Deployment

1. Ensure contract is thoroughly tested
2. Deploy using Clarinet or your preferred deployment method
3. Initialize arbitrator address
4. Verify contract deployment
5. Test basic operations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit pull request with comprehensive tests
4. Ensure all tests pass
5. Update documentation as needed
