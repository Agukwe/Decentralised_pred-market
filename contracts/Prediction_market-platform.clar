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
;; Helper to add or update a liquidity provider
(define-private (add-or-update-provider 
  (providers (list 50 { provider: principal, amount: uint, share-percentage: uint }))
  (user principal)
  (amount uint)
  (share-pct uint))
  
  (let ((provider-index (find-provider-index providers user u0)))
    (if (is-some provider-index)
      ;; Update existing provider
      (update-provider-at-index providers (unwrap-panic provider-index) user amount share-pct)
      ;; Add new provider
      (append providers { provider: user, amount: amount, share-percentage: share-pct })
    )
  )
)

;; Find a provider's index in the list
(define-private (find-provider-index 
  (providers (list 50 { provider: principal, amount: uint, share-percentage: uint }))
  (user principal)
  (current-index uint))
  
  (if (>= current-index (len providers))
    none
    (if (is-eq user (get provider (unwrap-panic (element-at providers current-index))))
      (some current-index)
      (find-provider-index providers user (+ current-index u1))
    )
  )
)

;; Update a provider at a specific index
(define-private (update-provider-at-index
  (providers (list 50 { provider: principal, amount: uint, share-percentage: uint }))
  (index uint)
  (user principal)
  (new-amount uint)
  (new-share-pct uint))
  
  (let (
    (current-provider (unwrap-panic (element-at providers index)))
    (current-amount (get amount current-provider))
    (updated-provider {
      provider: user,
      amount: (+ current-amount new-amount),
      share-percentage: new-share-pct
    })
  )
    (replace-at providers index updated-provider)
  )
)

;; Buy shares of a specific outcome
(define-public (buy-shares (market-id uint) (outcome-id uint) (amount uint))
  (let (
    (user tx-sender)
    (market (unwrap! (map-get? markets { market-id: market-id }) err-market-not-found))
    (shares (unwrap! (map-get? outcome-shares { market-id: market-id, outcome-id: outcome-id }) err-invalid-outcome))
    (position (default-to {
      outcomes-owned: (list),
      total-invested: u0
    } (map-get? positions { market-id: market-id, user: user })))
  )
    ;; Validate conditions
    (asserts! (< block-height (get closing-time market)) err-market-closed)
    (asserts! (not (get resolved market)) err-market-resolved)
    (asserts! (>= amount (get min-trade-amount market)) err-invalid-parameters)
    (asserts! (< outcome-id (len (get outcomes market))) err-invalid-outcome)
    
    ;; Transfer STX from user
    (try! (stx-transfer? amount user (as-contract tx-sender)))
    
    ;; Calculate shares to mint (simple linear formula for now)
    ;; In a production system, this would use a more sophisticated AMM algorithm
    (let (
      (share-price (get price shares))
      (shares-to-mint (/ (* amount u100000000) share-price))
      (fee-amount (/ (* amount (get fee-percentage market)) u10000))
      (protocol-fee (/ (* amount (var-get protocol-fee-percentage)) u10000))
      (net-amount (- amount (+ fee-amount protocol-fee)))
    )
      ;; Update shares data
      (map-set outcome-shares
        { market-id: market-id, outcome-id: outcome-id }
        {
          total-shares: (+ (get total-shares shares) shares-to-mint),
          ;; Simple price impact - price increases as more shares are bought
          price: (+ share-price (/ (* amount u1000000) (get total-value-locked market)))
        }
      )
      ;; Update user's position
      (map-set positions
        { market-id: market-id, user: user }
        {
          outcomes-owned: (remove-shares-from-position (get outcomes-owned position) outcome-id shares-to-sell),
          total-invested: (get total-invested position) ;; Keep track of total investment
        }
      )
      
      ;; Update market TVL
      (map-set markets
        { market-id: market-id }
        (merge market { total-value-locked: (- (get total-value-locked market) net-payout) })
      )
      
      ;; Pay fees
      (try! (as-contract (stx-transfer? protocol-fee (as-contract tx-sender) (var-get treasury-address))))
      (try! (as-contract (stx-transfer? fee-amount (as-contract tx-sender) (get creator market))))
      
      ;; Pay user
      (try! (as-contract (stx-transfer? net-payout (as-contract tx-sender) user)))
      
      (ok { amount-received: net-payout })
    )
  )
)

;; Helper to get user's shares for a specific outcome
(define-private (get-user-outcome-shares 
  (outcomes (list 10 { outcome-id: uint, shares: uint }))
  (outcome-id uint))
  
  (default-to u0 (get shares (find-outcome outcomes outcome-id)))
)

;; Helper to find outcome in a list
(define-private (find-outcome
  (outcomes (list 10 { outcome-id: uint, shares: uint }))
  (outcome-id uint))
  
  (unwrap-panic 
    (find outcome-matches outcomes)
    { outcome-id: u0, shares: u0 }
  )
)

;; Helper to check if outcome matches
(define-private (outcome-matches (outcome { outcome-id: uint, shares: uint }))
  (is-eq (get outcome-id outcome) outcome-id)
)

;; Helper to remove shares from position
(define-private (remove-shares-from-position
  (outcomes (list 10 { outcome-id: uint, shares: uint }))
  (outcome-id uint)
  (shares-to-remove uint))
  
  (let (
    (position-index (unwrap-panic (find-outcome-position outcomes outcome-id u0)))
    (current-position (unwrap-panic (element-at outcomes position-index)))
    (current-shares (get shares current-position))
  )
    (if (> current-shares shares-to-remove)
      ;; Update with remaining shares
      (replace-at outcomes position-index { 
        outcome-id: outcome-id, 
        shares: (- current-shares shares-to-remove) 
      })
      ;; Remove the position entirely
      (filter remove-outcome-by-id outcomes)
    )
  )
)

;; Helper to filter out an outcome
(define-private (remove-outcome-by-id (outcome { outcome-id: uint, shares: uint }))
  (not (is-eq (get outcome-id outcome) outcome-id))
)

;; Oracle resolution
(define-public (resolve-market (market-id uint) (outcome-id uint))
  (let (
    (oracle tx-sender)
    (market (unwrap! (map-get? markets { market-id: market-id }) err-market-not-found))
  )
    ;; Validate conditions
    (asserts! (is-eq oracle (get oracle market)) err-not-authorized)
    (asserts! (>= block-height (get closing-time market)) err-market-not-closed)
    (asserts! (not (get resolved market)) err-market-resolved)
    (asserts! (< outcome-id (len (get outcomes market))) err-invalid-outcome)
    
    ;; Set resolution outcome and start dispute period
    (map-set markets
      { market-id: market-id }
      (merge market { 
        resolution-outcome: (some outcome-id),
        dispute-resolution-timestamp: (+ block-height (get dispute-period-length market))
      })
    )
    
    ;; Pay oracle fee
    (try! (as-contract (stx-transfer? (get oracle-fee market) (as-contract tx-sender) oracle)))
    
    (ok true)
  )
)

;; Dispute market resolution
(define-public (dispute-resolution (market-id uint) (proposed-outcome uint) (stake-amount uint))
  (let (
    (disputer tx-sender)
    (market (unwrap! (map-get? markets { market-id: market-id }) err-market-not-found))
    (min-stake (var-get min-dispute-stake))
  )
    ;; Validate conditions
    (asserts! (is-some (get resolution-outcome market)) err-market-not-resolving)
    (asserts! (< block-height (get dispute-resolution-timestamp market)) err-dispute-period-ended)
    (asserts! (>= stake-amount min-stake) err-invalid-dispute-stake)
    (asserts! (< proposed-outcome (len (get outcomes market))) err-invalid-outcome)
    (asserts! (not (is-eq proposed-outcome (unwrap-panic (get resolution-outcome market)))) err-invalid-outcome)
    (asserts! (is-none (map-get? disputes { market-id: market-id, disputer: disputer })) err-dispute-exists)
    
    ;; Transfer stake from disputer
    (try! (stx-transfer? stake-amount disputer (as-contract tx-sender)))
    
    ;; Record dispute
    (map-set disputes
      { market-id: market-id, disputer: disputer }
      {
        proposed-outcome: proposed-outcome,
        stake-amount: stake-amount,
        dispute-time: block-height,
        resolved: false,
        won: false
      }
    )
    
    (ok true)
  )
)
;; Finalize market after dispute period
(define-public (finalize-market (market-id uint))
  (let (
    (market (unwrap! (map-get? markets { market-id: market-id }) err-market-not-found))
  )
    ;; Validate conditions
    (asserts! (is-some (get resolution-outcome market)) err-market-not-resolving)
    (asserts! (>= block-height (get dispute-resolution-timestamp market)) err-dispute-period-active)
    (asserts! (not (get resolved market)) err-market-resolved)
    
    ;; Finalize market
    (map-set markets
      { market-id: market-id }
      (merge market { resolved: true })
    )
    
    (ok true)
  )
)

;; Claim winnings after market is resolved
(define-public (claim-winnings (market-id uint))
  (let (
    (user tx-sender)
    (market (unwrap! (map-get? markets { market-id: market-id }) err-market-not-found))
    (position (unwrap! (map-get? positions { market-id: market-id, user: user }) err-position-not-found))
  )
    ;; Validate conditions
    (asserts! (get resolved market) err-market-not-resolved)
    (asserts! (is-some (get resolution-outcome market)) err-market-not-resolved)
    
    (let (
      (winning-outcome (unwrap-panic (get resolution-outcome market)))
      (user-shares (get-user-outcome-shares (get outcomes-owned position) winning-outcome))
      (total-shares (get total-shares (unwrap-panic (map-get? outcome-shares { market-id: market-id, outcome-id: winning-outcome }))))
      (tvl (get total-value-locked market))
    )
      ;; Only winners can claim
      (asserts! (> user-shares u0) err-shares-not-found)
      
      ;; Calculate winnings proportionally to shares owned
      (let (
        (winnings (/ (* tvl user-shares) total-shares))
      )
        ;; Pay winnings
        (try! (as-contract (stx-transfer? winnings (as-contract tx-sender) user)))
        
        ;; Clear position
        (map-delete positions { market-id: market-id, user: user })
        
        (ok { amount-claimed: winnings })
      )
    )
  )
)

;; Remove liquidity after market is resolved
(define-public (remove-liquidity (market-id uint))
  (let (
    (user tx-sender)
    (market (unwrap! (map-get? markets { market-id: market-id }) err-market-not-found))
    (liquidity-pool (unwrap! (map-get? liquidity-pools { market-id: market-id }) err-market-not-found))
    (provider-index (unwrap! (find-provider-index (get liquidity-providers liquidity-pool) user u0) err-not-authorized))
  )
    ;; Validate conditions
    (asserts! (get resolved market) err-market-not-resolved)
    
    (let (
      (provider-data (unwrap-panic (element-at (get liquidity-providers liquidity-pool) provider-index)))
      (share-percentage (get share-percentage provider-data))
      (remaining-tvl (get total-value-locked market))
      (amount-to-return (/ (* remaining-tvl share-percentage) u10000))
    )
      ;; Pay liquidity provider
      (try! (as-contract (stx-transfer? amount-to-return (as-contract tx-sender) user)))
      
      ;; Update liquidity pool by removing the provider
      (map-set liquidity-pools
        { market-id: market-id }
        {
          total-liquidity: (- (get total-liquidity liquidity-pool) amount-to-return),
          liquidity-providers: (filter remove-provider-by-principal (get liquidity-providers liquidity-pool))
        }
      )
      
      ;; Update market TVL
      (map-set markets
        { market-id: market-id }
        (merge market { total-value-locked: (- remaining-tvl amount-to-return) })
      )
      
      (ok { amount-returned: amount-to-return })
    )
  )
)

;; Helper to filter out a provider by principal
(define-private (remove-provider-by-principal (provider { provider: principal, amount: uint, share-percentage: uint }))
  (not (is-eq (get provider provider) tx-sender))
)

;; Governance functions

;; Add a new oracle
(define-public (add-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-oracles 
      { oracle: oracle } 
      { authorized: true, reputation-score: u100 }
    )
    (ok true)
  )
)

;; Remove an oracle
(define-public (remove-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-delete authorized-oracles { oracle: oracle })
    (ok true)
  )
)

;; Update oracle reputation
(define-public (update-oracle-reputation (oracle principal) (new-score uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-score u100) err-invalid-parameters)
    
    (let ((oracle-data (unwrap! (map-get? authorized-oracles { oracle: oracle }) err-unauthorized-oracle)))
      (map-set authorized-oracles
        { oracle: oracle }
        (merge oracle-data { reputation-score: new-score })
      )
      (ok true)
    )
  )
)

;; Update minimum dispute stake
(define-public (set-min-dispute-stake (new-stake uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-dispute-stake new-stake)
    (ok true)
  )
)

;; Update default dispute period length
(define-public (set-default-dispute-period-length (new-length uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set default-dispute-period-length new-length)
    (ok true)
  )
)

;; Update protocol fee percentage
(define-public (set-protocol-fee-percentage (new-percentage uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)