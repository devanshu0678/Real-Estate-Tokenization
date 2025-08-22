;; Real Estate Tokenization Contract
;; A smart contract for tokenizing real estate properties into fractional ownership tokens

;; Define the property token
(define-fungible-token property-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-property-not-found (err u104))
(define-constant err-already-tokenized (err u105))

;; Property data structure
(define-map properties uint {
  property-id: uint,
  property-address: (string-ascii 100),
  property-value: uint,
  total-tokens: uint,
  owner: principal,
  is-tokenized: bool
})

;; Property counter
(define-data-var property-counter uint u0)

;; Token holders mapping
(define-map token-holders {property-id: uint, holder: principal} uint)

;; Function 1: Tokenize a real estate property
;; This function creates tokens representing fractional ownership of a property
(define-public (tokenize-property (property-address (string-ascii 100)) (property-value uint) (total-tokens uint))
  (let 
    ((property-id (+ (var-get property-counter) u1)))
    (begin
      ;; Validate inputs
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      (asserts! (> property-value u0) err-invalid-amount)
      (asserts! (> total-tokens u0) err-invalid-amount)
      
      ;; Create property record
      (map-set properties property-id {
        property-id: property-id,
        property-address: property-address,
        property-value: property-value,
        total-tokens: total-tokens,
        owner: tx-sender,
        is-tokenized: true
      })
      
      ;; Mint tokens to the property owner
      (try! (ft-mint? property-token total-tokens tx-sender))
      
      ;; Update property counter
      (var-set property-counter property-id)
      
      ;; Record token ownership
      (map-set token-holders {property-id: property-id, holder: tx-sender} total-tokens)
      
      (ok property-id))))

;; Function 2: Transfer property tokens (fractional ownership transfer)
;; This function allows holders to transfer their fractional ownership to others
(define-public (transfer-property-tokens (property-id uint) (amount uint) (recipient principal))
  (let 
    ((sender-tokens (default-to u0 (map-get? token-holders {property-id: property-id, holder: tx-sender})))
     (recipient-tokens (default-to u0 (map-get? token-holders {property-id: property-id, holder: recipient})))
     (property-info (map-get? properties property-id)))
    (begin
      ;; Validate property exists
      (asserts! (is-some property-info) err-property-not-found)
      
      ;; Validate transfer amount
      (asserts! (> amount u0) err-invalid-amount)
      (asserts! (>= sender-tokens amount) err-insufficient-balance)
      
      ;; Transfer fungible tokens
      (try! (ft-transfer? property-token amount tx-sender recipient))
      
      ;; Update token holders mapping
      (map-set token-holders {property-id: property-id, holder: tx-sender} (- sender-tokens amount))
      (map-set token-holders {property-id: property-id, holder: recipient} (+ recipient-tokens amount))
      
      (ok true))))

;; Read-only functions for querying data

;; Get property information
(define-read-only (get-property-info (property-id uint))
  (map-get? properties property-id))

;; Get token balance for a specific property and holder
(define-read-only (get-property-token-balance (property-id uint) (holder principal))
  (default-to u0 (map-get? token-holders {property-id: property-id, holder: holder})))

;; Get total token balance for any holder
(define-read-only (get-total-token-balance (holder principal))
  (ft-get-balance property-token holder))

;; Get total number of properties tokenized
(define-read-only (get-total-properties)
  (var-get property-counter))