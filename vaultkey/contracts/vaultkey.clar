;; VaultKey - Decentralized Time-locked Vault
;; A contract for creating time-locked vaults for tokens and NFTs

(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-VAULT-NOT-FOUND (err u2))
(define-constant ERR-VAULT-LOCKED (err u3))
(define-constant ERR-INVALID-UNLOCK-HEIGHT (err u4))
(define-constant ERR-ZERO-AMOUNT (err u5))

;; Data Maps
(define-map vaults
  { vault-id: uint }
  {
    owner: principal,
    unlock-height: uint,
    token-amount: uint,
    nft-id: (optional uint)
  }
)

(define-data-var vault-nonce uint u0)

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

;; Public functions
(define-public (create-token-vault (unlock-height uint) (token-amount uint))
  (let (
    (vault-id (var-get vault-nonce))
    (current-height block-height)
  )
    ;; Check that unlock height is in the future
    (asserts! (> unlock-height current-height) ERR-INVALID-UNLOCK-HEIGHT)
    ;; Check that amount is not zero
    (asserts! (> token-amount u0) ERR-ZERO-AMOUNT)
    
    ;; Transfer tokens to contract
    (try! (stx-transfer? token-amount tx-sender (as-contract tx-sender)))
    
    ;; Create vault
    (map-set vaults
      { vault-id: vault-id }
      {
        owner: tx-sender,
        unlock-height: unlock-height,
        token-amount: token-amount,
        nft-id: none
      }
    )
    
    ;; Increment nonce
    (var-set vault-nonce (+ vault-id u1))
    (ok vault-id)
  )
)

(define-public (create-nft-vault (unlock-height uint) (nft-id uint))
  (let (
    (vault-id (var-get vault-nonce))
    (current-height block-height)
  )
    ;; Check that unlock height is in the future
    (asserts! (> unlock-height current-height) ERR-INVALID-UNLOCK-HEIGHT)
    
    ;; Create vault
    (map-set vaults
      { vault-id: vault-id }
      {
        owner: tx-sender,
        unlock-height: unlock-height,
        token-amount: u0,
        nft-id: (some nft-id)
      }
    )
    
    ;; Increment nonce
    (var-set vault-nonce (+ vault-id u1))
    (ok vault-id)
  )
)

(define-public (withdraw-from-vault (vault-id uint))
  (let (
    (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-NOT-FOUND))
    (current-height block-height)
  )
    ;; Check authorization
    (asserts! (is-eq tx-sender (get owner vault)) ERR-NOT-AUTHORIZED)
    ;; Check if vault is unlocked
    (asserts! (>= current-height (get unlock-height vault)) ERR-VAULT-LOCKED)
    
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

;; Get vault details
(define-read-only (get-vault-details (vault-id uint))
  (match (map-get? vaults { vault-id: vault-id })
    vault (ok {
      owner: (get owner vault),
      unlock-height: (get unlock-height vault),
      token-amount: (get token-amount vault),
      nft-id: (get nft-id vault)
    })
    ERR-VAULT-NOT-FOUND
  )
)