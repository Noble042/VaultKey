;; VaultKey - Decentralized Time-locked Vault
;; A contract for creating time-locked vaults for tokens and NFTs with multi-sig and emergency unlock

(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-VAULT-NOT-FOUND (err u2))
(define-constant ERR-VAULT-LOCKED (err u3))
(define-constant ERR-INVALID-UNLOCK-HEIGHT (err u4))
(define-constant ERR-ZERO-AMOUNT (err u5))
(define-constant ERR-INVALID-SIGNERS (err u6))
(define-constant ERR-ALREADY-SIGNED (err u7))
(define-constant ERR-INSUFFICIENT-SIGNATURES (err u8))
(define-constant ERR-NOT-ARBITRATOR (err u9))
(define-constant ERR-EMERGENCY-NOT-ACTIVE (err u10))

;; Data Maps
(define-map vaults
  { vault-id: uint }
  {
    owner: principal,
    unlock-height: uint,
    token-amount: uint,
    nft-id: (optional uint),
    required-signatures: uint,
    signers: (list 5 principal),
    emergency-active: bool
  }
)

(define-map vault-signatures
  { vault-id: uint, signer: principal }
  { signed: bool }
)

(define-data-var vault-nonce uint u0)
(define-data-var contract-owner principal tx-sender)
(define-data-var arbitrator principal tx-sender)

;; Read-only functions
(define-read-only (get-vault (vault-id uint))
  (map-get? vaults { vault-id: vault-id })
)

(define-read-only (get-vault-owner (vault-id uint))
  (ok (get owner (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-NOT-FOUND)))
)

(define-read-only (is-vault-unlocked (vault-id uint))
  (let (
    (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-NOT-FOUND))
    (current-height block-height)
  )
    (ok (>= current-height (get unlock-height vault)))
  )
)

(define-read-only (has-signed (vault-id uint) (signer principal))
  (match (map-get? vault-signatures { vault-id: vault-id, signer: signer })
    signature (get signed signature)
    false
  )
)

(define-private (check-signer (vault-id uint) (signer (optional principal)))
  (match signer
    signed (if (has-signed vault-id signed) u1 u0)
    u0)
)

(define-private (count-signatures (vault-id uint) (signers (list 5 principal)))
  (let 
    (
      (signer-0 (element-at signers u0))
      (signer-1 (element-at signers u1))
      (signer-2 (element-at signers u2))
      (signer-3 (element-at signers u3))
      (signer-4 (element-at signers u4))
    )
    (+
      (check-signer vault-id signer-0)
      (check-signer vault-id signer-1)
      (check-signer vault-id signer-2)
      (check-signer vault-id signer-3)
      (check-signer vault-id signer-4)
    )
  )
)

(define-read-only (get-signature-count (vault-id uint))
  (match (map-get? vaults { vault-id: vault-id })
    vault (ok (count-signatures vault-id (get signers vault)))
    ERR-VAULT-NOT-FOUND)
)

;; Public functions
(define-public (create-token-vault (unlock-height uint) (token-amount uint) (required-sigs uint) (signers (list 5 principal)))
  (let (
    (vault-id (var-get vault-nonce))
    (current-height block-height)
  )
    ;; Validation checks
    (asserts! (> unlock-height current-height) ERR-INVALID-UNLOCK-HEIGHT)
    (asserts! (> token-amount u0) ERR-ZERO-AMOUNT)
    (asserts! (>= (len signers) required-sigs) ERR-INVALID-SIGNERS)
    
    ;; Transfer tokens to contract
    (try! (stx-transfer? token-amount tx-sender (as-contract tx-sender)))
    
    ;; Create vault
    (map-set vaults
      { vault-id: vault-id }
      {
        owner: tx-sender,
        unlock-height: unlock-height,
        token-amount: token-amount,
        nft-id: none,
        required-signatures: required-sigs,
        signers: signers,
        emergency-active: false
      }
    )
    
    ;; Increment nonce
    (var-set vault-nonce (+ vault-id u1))
    (ok vault-id)
  )
)

(define-public (create-nft-vault (unlock-height uint) (nft-id uint) (required-sigs uint) (signers (list 5 principal)))
  (let (
    (vault-id (var-get vault-nonce))
    (current-height block-height)
  )
    ;; Validation checks
    (asserts! (> unlock-height current-height) ERR-INVALID-UNLOCK-HEIGHT)
    (asserts! (>= (len signers) required-sigs) ERR-INVALID-SIGNERS)
    
    ;; Create vault
    (map-set vaults
      { vault-id: vault-id }
      {
        owner: tx-sender,
        unlock-height: unlock-height,
        token-amount: u0,
        nft-id: (some nft-id),
        required-signatures: required-sigs,
        signers: signers,
        emergency-active: false
      }
    )
    
    ;; Increment nonce
    (var-set vault-nonce (+ vault-id u1))
    (ok vault-id)
  )
)

(define-public (sign-vault-withdrawal (vault-id uint))
  (let (
    (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-NOT-FOUND))
    (current-height block-height)
  )
    ;; Check if signer is authorized
    (asserts! (is-some (index-of (get signers vault) tx-sender)) ERR-NOT-AUTHORIZED)
    ;; Check if already signed
    (asserts! (is-none (map-get? vault-signatures { vault-id: vault-id, signer: tx-sender })) ERR-ALREADY-SIGNED)
    
    ;; Record signature
    (map-set vault-signatures
      { vault-id: vault-id, signer: tx-sender }
      { signed: true }
    )
    (ok true)
  )
)

(define-public (withdraw-from-vault (vault-id uint))
  (let (
    (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-NOT-FOUND))
    (current-height block-height)
    (signature-count (unwrap! (get-signature-count vault-id) ERR-VAULT-NOT-FOUND))
  )
    ;; Check authorization
    (asserts! (is-eq tx-sender (get owner vault)) ERR-NOT-AUTHORIZED)
    ;; Check if vault is unlocked or emergency active
    (asserts! (or 
      (>= current-height (get unlock-height vault))
      (get emergency-active vault)
    ) ERR-VAULT-LOCKED)
    ;; Check sufficient signatures
    (asserts! (>= signature-count (get required-signatures vault)) ERR-INSUFFICIENT-SIGNATURES)
    
    ;; Handle token withdrawal if there are tokens
    (if (> (get token-amount vault) u0)
      (try! (as-contract (stx-transfer? (get token-amount vault) tx-sender (get owner vault))))
      true
    )
    
    ;; Clear vault
    (map-delete vaults { vault-id: vault-id })
    (ok true)
  )
)

(define-public (initiate-emergency-unlock (vault-id uint))
  (let (
    (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-NOT-FOUND))
  )
    ;; Check if caller is arbitrator
    (asserts! (is-eq tx-sender (var-get arbitrator)) ERR-NOT-ARBITRATOR)
    
    ;; Set emergency flag
    (map-set vaults
      { vault-id: vault-id }
      (merge vault { emergency-active: true })
    )
    (ok true)
  )
)

(define-public (set-arbitrator (new-arbitrator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set arbitrator new-arbitrator)
    (ok true)
  )
)

(define-read-only (get-vault-details (vault-id uint))
  (match (map-get? vaults { vault-id: vault-id })
    vault (ok {
      owner: (get owner vault),
      unlock-height: (get unlock-height vault),
      token-amount: (get token-amount vault),
      nft-id: (get nft-id vault),
      required-signatures: (get required-signatures vault),
      signers: (get signers vault),
      emergency-active: (get emergency-active vault)
    })
    ERR-VAULT-NOT-FOUND
  )
)