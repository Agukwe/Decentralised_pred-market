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
