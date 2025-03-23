;; Decentralized Prediction Market Platform
;; A platform for creating and resolving prediction markets with a focus on real-world events

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-market-exists (err u102))
(define-constant err-market-not-found (err u103))
(define-constant err-invalid-parameters (err u104))
(define-constant err-market-closed (err u105))
(define-constant err-market-not-closed (err u106))
(define-constant err-market-resolved (err u107))
(define-constant err-market-not-resolved (err u108))
(define-constant err-position-already-exists (err u109))
(define-constant err-position-not-found (err u110))
(define-constant err-insufficient-funds (err u111))
(define-constant err-dispute-period-active (err u112))
(define-constant err-dispute-period-ended (err u113))
(define-constant err-dispute-exists (err u114))
(define-constant err-invalid-outcome (err u115))
(define-constant err-shares-not-found (err u116))
(define-constant err-invalid-dispute-stake (err u117))
(define-constant err-unauthorized-oracle (err u118))
(define-constant err-market-not-resolving (err u119))

;; Token for the protocol
(define-fungible-token prediction-token)

;; Market status enumeration
(define-data-var next-market-id uint u1)
;; Market structure
(define-map markets
  { market-id: uint }
  {
    creator: principal,
    description: (string-utf8 256),
    category: (string-ascii 32),
    outcomes: (list 10 (string-utf8 64)),
    creation-time: uint,
    resolution-time: uint,
    closing-time: uint,
    total-value-locked: uint,
    fee-percentage: uint,
    resolved: bool,
    resolution-outcome: (optional uint),
    oracle: principal,
    oracle-fee: uint,
    dispute-period-length: uint,
    dispute-resolution-timestamp: uint,
    min-trade-amount: uint,
    additional-data: (optional (string-utf8 256))
  }
)

;; Positions - tracking users' positions in markets
(define-map positions
  { market-id: uint, user: principal }
  {
    outcomes-owned: (list 10 { outcome-id: uint, shares: uint }), 
    total-invested: uint
  }
)

;; Market liquidity pool
(define-map liquidity-pools
  { market-id: uint }
  {
    total-liquidity: uint,
    liquidity-providers: (list 50 { provider: principal, amount: uint, share-percentage: uint })
  }
)

;; Outcome shares - tracks the total number of shares for each outcome in a market
(define-map outcome-shares
  { market-id: uint, outcome-id: uint }
  { total-shares: uint, price: uint }
)

;; Disputes tracking
(define-map disputes
  { market-id: uint, disputer: principal }
  {
    proposed-outcome: uint,
    stake-amount: uint,
    dispute-time: uint,
    resolved: bool,
    won: bool
  }
)

;; Authorized oracles
(define-map authorized-oracles
  { oracle: principal }
  { authorized: bool, reputation-score: uint }
)

;; Protocol parameters
(define-data-var min-dispute-stake uint u1000000) ;; 1 STX
(define-data-var default-dispute-period-length uint u1008) ;; ~7 days (144 blocks per day)
(define-data-var protocol-fee-percentage uint u100) ;; 1% (in basis points)
(define-data-var treasury-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Initialize contract
(define-public (initialize (initial-oracles (list 5 principal)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    ;; Register initial oracles
    (map register-oracle initial-oracles)
    
    ;; Mint initial tokens for liquidity
    (try! (ft-mint? prediction-token u1000000000 contract-owner))
    
    (ok true)
  )
)
;; Add a new oracle
(define-private (register-oracle (oracle principal))
  (map-set authorized-oracles 
    { oracle: oracle } 
    { authorized: true, reputation-score: u100 }
  )
)

;; Create a new prediction market
(define-public (create-market 
  (description (string-utf8 256))
  (category (string-ascii 32))
  (outcomes (list 10 (string-utf8 64)))
  (resolution-time uint)
  (closing-time uint)
  (fee-percentage uint)
  (oracle principal)
  (oracle-fee uint)
  (min-trade-amount uint)
  (additional-data (optional (string-utf8 256))))
  
  (let (
    (market-id (var-get next-market-id))
    (creator tx-sender)
    (dispute-period-length (var-get default-dispute-period-length))
  )
    ;; Validate parameters
    (asserts! (> (len outcomes) u1) err-invalid-parameters) ;; At least 2 outcomes
    (asserts! (< fee-percentage u1000) err-invalid-parameters) ;; Max 10% fee
    (asserts! (>= resolution-time closing-time) err-invalid-parameters) ;; Resolution must be after closing
    (asserts! (> closing-time block-height) err-invalid-parameters) ;; Closing must be in the future
    (asserts! (default-to false (get authorized (map-get? authorized-oracles { oracle: oracle }))) err-unauthorized-oracle)
    
    ;; Charge market creation fee (fixed at 10 STX for now)
    (try! (stx-transfer? u10000000 creator contract-owner))
    
    ;; Create the market
    (map-set markets
      { market-id: market-id }
      {
        creator: creator,
        description: description,
        category: category,
        outcomes: outcomes,
        creation-time: block-height,
        resolution-time: resolution-time,
        closing-time: closing-time,
        total-value-locked: u0,
        fee-percentage: fee-percentage,
        resolved: false,
        resolution-outcome: none,
        oracle: oracle,
        oracle-fee: oracle-fee,
        dispute-period-length: dispute-period-length,
        dispute-resolution-timestamp: u0,
        min-trade-amount: min-trade-amount,
        additional-data: additional-data
      }
    )
    
    ;; Initialize outcome shares
    (initialize-outcome-shares market-id outcomes)
    
    ;; Increment market ID
    (var-set next-market-id (+ market-id u1))
    
    (ok market-id)
  )
)

;; Helper to initialize outcome shares
(define-private (initialize-outcome-shares (market-id uint) (outcomes (list 10 (string-utf8 64))))
  (let ((outcome-count (len outcomes)))
    (map-outcome-initializer market-id u0 outcome-count)
  )
)

;; Helper for outcome initialization
(define-private (map-outcome-initializer (market-id uint) (current-id uint) (max-id uint))
  (if (>= current-id max-id)
    true
    (begin
      (map-set outcome-shares
        { market-id: market-id, outcome-id: current-id }
        { total-shares: u0, price: u50000000 } ;; Initial price at 50%
      )
      (map-outcome-initializer market-id (+ current-id u1) max-id)
    )
  )
)

;; Add liquidity to the market
(define-public (add-liquidity (market-id uint) (amount uint))
  (let (
    (user tx-sender)
    (market (unwrap! (map-get? markets { market-id: market-id }) err-market-not-found))
    (liquidity-pool (default-to { 
      total-liquidity: u0, 
      liquidity-providers: (list) 
    } (map-get? liquidity-pools { market-id: market-id })))
    (current-total (get total-liquidity liquidity-pool))
    (current-providers (get liquidity-providers liquidity-pool))
  )
    ;; Ensure market isn't closed
    (asserts! (< block-height (get closing-time market)) err-market-closed)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? amount user (as-contract tx-sender)))
    
    ;; Update liquidity pool
    (let (
      (new-total (+ current-total amount))
      (provider-share-pct (if (is-eq current-total u0)
                             u10000 ;; First provider gets 100%
                             (/ (* amount u10000) new-total))) ;; Calculate share percentage
      (updated-providers (add-or-update-provider current-providers user amount provider-share-pct))
    )
      (map-set liquidity-pools
        { market-id: market-id }
        {
          total-liquidity: new-total,
          liquidity-providers: updated-providers
        }
      )
      
      ;; Update market TVL
      (map-set markets
        { market-id: market-id }
        (merge market { total-value-locked: (+ (get total-value-locked market) amount) })
      )
      
      (ok { share-percentage: provider-share-pct })
    )
  )
)