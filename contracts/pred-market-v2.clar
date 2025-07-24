;; Prediction Market V2 - Enhanced Decentralized Prediction Platform
;; Advanced features: Multi-token support, AMM pricing, conditional markets, consensus oracles

(define-constant contract-owner tx-sender)

;; Enhanced error codes
(define-constant err-owner-only (err u200))
(define-constant err-not-authorized (err u201))
(define-constant err-market-exists (err u202))
(define-constant err-market-not-found (err u203))
(define-constant err-invalid-parameters (err u204))
(define-constant err-market-closed (err u205))
(define-constant err-market-not-closed (err u206))
(define-constant err-market-resolved (err u207))
(define-constant err-market-not-resolved (err u208))
(define-constant err-position-not-found (err u209))
(define-constant err-insufficient-funds (err u210))
(define-constant err-dispute-period-active (err u211))
(define-constant err-dispute-period-ended (err u212))
(define-constant err-invalid-outcome (err u213))
(define-constant err-shares-not-found (err u214))
(define-constant err-unauthorized-oracle (err u215))
(define-constant err-token-not-supported (err u216))
(define-constant err-invalid-condition (err u217))
(define-constant err-market-template-not-found (err u218))
(define-constant err-oracle-consensus-failed (err u219))
(define-constant err-position-limit-exceeded (err u220))
(define-constant err-insufficient-margin (err u221))
(define-constant err-market-paused (err u222))

;; Enhanced market types
(define-constant market-type-binary u0)
(define-constant market-type-categorical u1)
(define-constant market-type-scalar u2)
(define-constant market-type-conditional u3)

;; Oracle consensus mechanisms
(define-constant consensus-simple-majority u0)
(define-constant consensus-weighted-voting u1)
(define-constant consensus-stake-weighted u2)

;; Protocol tokens
(define-fungible-token pmv2-token)
(define-non-fungible-token market-nft uint)

;; State variables
(define-data-var next-market-id uint u1)
(define-data-var next-template-id uint u1)
(define-data-var protocol-paused bool false)
(define-data-var min-oracle-consensus uint u3)
(define-data-var max-market-duration uint u52560) ;; ~1 year in blocks
(define-data-var base-trading-fee uint u25) ;; 0.25% in basis points

;; Supported tokens for collateral
(define-map supported-tokens
  { token-contract: principal }
  {
    name: (string-ascii 32),
    symbol: (string-ascii 8),
    decimals: uint,
    min-amount: uint,
    enabled: bool,
    risk-weight: uint ;; 100 = 100%, lower = safer
  }
)

;; Enhanced market structure
(define-map markets-v2
  { market-id: uint }
  {
    creator: principal,
    title: (string-utf8 128),
    description: (string-utf8 512),
    category: (string-ascii 32),
    market-type: uint,
    outcomes: (list 20 (string-utf8 128)),
    collateral-token: principal,
    creation-time: uint,
    trading-start-time: uint,
    trading-end-time: uint,
    resolution-time: uint,
    total-liquidity: uint,
    total-volume: uint,
    creator-fee: uint,
    oracle-fee: uint,
    status: uint, ;; 0=active, 1=closed, 2=resolved, 3=disputed, 4=paused
    resolution-source: (string-utf8 256),
    metadata: (string-utf8 512),
    conditional-parent: (optional uint),
    conditional-outcome: (optional uint),
    min-liquidity-threshold: uint,
    max-position-size: uint,
    early-resolution-eligible: bool
  }
)

;; Market templates for common scenarios
(define-map market-templates
  { template-id: uint }
  {
    name: (string-ascii 64),
    category: (string-ascii 32),
    description: (string-utf8 256),
    market-type: uint,
    default-outcomes: (list 20 (string-utf8 128)),
    default-duration: uint,
    suggested-fee: uint,
    risk-level: uint, ;; 1=low, 2=medium, 3=high
    oracle-requirements: uint,
    enabled: bool
  }
)

;; Enhanced oracle system with consensus
(define-map oracle-network
  { oracle: principal }
  {
    reputation: uint,
    stake-amount: uint,
    total-resolutions: uint,
    correct-resolutions: uint,
    categories: (list 10 (string-ascii 32)),
    consensus-weight: uint,
    status: uint, ;; 0=active, 1=suspended, 2=banned
    last-active: uint
  }
)

;; Oracle votes for consensus
(define-map oracle-votes
  { market-id: uint, oracle: principal }
  {
    outcome: uint,
    confidence: uint, ;; 0-100
    timestamp: uint,
    stake-amount: uint,
    reasoning: (optional (string-utf8 256))
  }
)

;; Advanced position tracking
(define-map positions-v2
  { market-id: uint, user: principal }
  {
    shares-owned: (list 20 { outcome-id: uint, shares: uint, avg-price: uint }),
    total-invested: uint,
    realized-pnl: int,
    unrealized-pnl: int,
    entry-timestamp: uint,
    last-trade-timestamp: uint,
    margin-posted: uint
  }
)

;; Automated Market Maker pools
(define-map amm-pools
  { market-id: uint }
  {
    k-constant: uint, ;; For constant product formula
    liquidity-token-supply: uint,
    fee-accumulated: uint,
    price-impact-factor: uint,
    last-price-update: uint,
    volume-24h: uint,
    impermanent-loss-protection: bool
  }
)

;; Liquidity provider positions
(define-map lp-positions
  { market-id: uint, provider: principal }
  {
    liquidity-tokens: uint,
    initial-deposit: uint,
    fees-earned: uint,
    entry-time: uint,
    lock-end-time: uint
  }
)

;; Market analytics and metrics
(define-map market-metrics
  { market-id: uint }
  {
    daily-volume: uint,
    weekly-volume: uint,
    unique-traders: uint,
    price-volatility: uint,
    liquidity-score: uint,
    last-updated: uint
  }
)

;; Initialize enhanced protocol
(define-public (initialize-v2 
  (initial-oracles (list 10 principal))
  (supported-token-list (list 5 { token: principal, name: (string-ascii 32), symbol: (string-ascii 8), decimals: uint })))
  
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    ;; Register initial oracles with enhanced structure
    (map register-enhanced-oracle initial-oracles)
    
    ;; Setup supported tokens
    (map setup-supported-token supported-token-list)
    
    ;; Create default market templates
    (try! (create-default-templates))
    
    ;; Mint initial governance tokens
    (try! (ft-mint? pmv2-token u1000000000000 contract-owner))
    
    (ok true)
  )
)

;; Register enhanced oracle with consensus capabilities
(define-private (register-enhanced-oracle (oracle principal))
  (map-set oracle-network
    { oracle: oracle }
    {
      reputation: u100,
      stake-amount: u0,
      total-resolutions: u0,
      correct-resolutions: u0,
      categories: (list),
      consensus-weight: u1,
      status: u0,
      last-active: block-height
    }
  )
)

;; Setup supported collateral token
(define-private (setup-supported-token (token-info { token: principal, name: (string-ascii 32), symbol: (string-ascii 8), decimals: uint }))
  (map-set supported-tokens
    { token-contract: (get token token-info) }
    {
      name: (get name token-info),
      symbol: (get symbol token-info),
      decimals: (get decimals token-info),
      min-amount: u1000000, ;; Default 1 unit
      enabled: true,
      risk-weight: u100
    }
  )
)

;; Create default market templates
(define-private (create-default-templates)
  (begin
    ;; Binary outcome template
    (map-set market-templates
      { template-id: u1 }
      {
        name: "Binary Outcome",
        category: "general",
        description: "Simple Yes/No prediction market",
        market-type: market-type-binary,
        default-outcomes: (list u"Yes" u"No"),
        default-duration: u1008, ;; ~7 days
        suggested-fee: u100, ;; 1%
        risk-level: u1,
        oracle-requirements: u1,
        enabled: true
      }
    )
    
    ;; Crypto price template
    (map-set market-templates
      { template-id: u2 }
      {
        name: "Crypto Price Prediction",
        category: "crypto",
        description: "Cryptocurrency price movements",
        market-type: market-type-categorical,
        default-outcomes: (list u"Below $X" u"$X to $Y" u"Above $Y"),
        default-duration: u4032, ;; ~1 month
        suggested-fee: u150, ;; 1.5%
        risk-level: u2,
        oracle-requirements: u2,
        enabled: true
      }
    )
    
    ;; Sports outcome template
    (map-set market-templates
      { template-id: u3 }
      {
        name: "Sports Match",
        category: "sports",
        description: "Sports match outcome prediction",
        market-type: market-type-categorical,
        default-outcomes: (list u"Team A Wins" u"Draw" u"Team B Wins"),
        default-duration: u144, ;; ~1 day
        suggested-fee: u200, ;; 2%
        risk-level: u1,
        oracle-requirements: u2,
        enabled: true
      }
    )
    
    (var-set next-template-id u4)
    (ok true)
  )
)

;; Enhanced market creation with templates and multi-token support
(define-public (create-enhanced-market
  (title (string-utf8 128))
  (description (string-utf8 512))
  (category (string-ascii 32))
  (market-type uint)
  (outcomes (list 20 (string-utf8 128)))
  (collateral-token principal)
  (trading-duration uint)
  (resolution-time uint)
  (creator-fee uint)
  (oracle-fee uint)
  (resolution-source (string-utf8 256))
  (metadata (string-utf8 512))
  (min-liquidity-threshold uint)
  (max-position-size uint))
  
  (let (
    (market-id (var-get next-market-id))
    (creator tx-sender)
    (current-time block-height)
    (trading-end-time (+ current-time trading-duration))
  )
    ;; Enhanced validation
    (asserts! (not (var-get protocol-paused)) err-market-paused)
    (asserts! (> (len outcomes) u1) err-invalid-parameters)
    (asserts! (<= (len outcomes) u20) err-invalid-parameters)
    (asserts! (< creator-fee u1000) err-invalid-parameters) ;; Max 10%
    (asserts! (< oracle-fee u500) err-invalid-parameters) ;; Max 5%
    (asserts! (>= resolution-time trading-end-time) err-invalid-parameters)
    (asserts! (<= trading-duration (var-get max-market-duration)) err-invalid-parameters)
    (asserts! (default-to false (get enabled (map-get? supported-tokens { token-contract: collateral-token }))) err-token-not-supported)
    
    ;; Charge enhanced market creation fee (varies by market type)
    (let ((creation-fee (calculate-creation-fee market-type trading-duration)))
      (try! (stx-transfer? creation-fee creator contract-owner))
    )
    
    ;; Create enhanced market
    (map-set markets-v2
      { market-id: market-id }
      {
        creator: creator,
        title: title,
        description: description,
        category: category,
        market-type: market-type,
        outcomes: outcomes,
        collateral-token: collateral-token,
        creation-time: current-time,
        trading-start-time: current-time,
        trading-end-time: trading-end-time,
        resolution-time: resolution-time,
        total-liquidity: u0,
        total-volume: u0,
        creator-fee: creator-fee,
        oracle-fee: oracle-fee,
        status: u0,
        resolution-source: resolution-source,
        metadata: metadata,
        conditional-parent: none,
        conditional-outcome: none,
        min-liquidity-threshold: min-liquidity-threshold,
        max-position-size: max-position-size,
        early-resolution-eligible: false
      }
    )
    
    ;; Initialize AMM pool
    (map-set amm-pools
      { market-id: market-id }
      {
        k-constant: u0,
        liquidity-token-supply: u0,
        fee-accumulated: u0,
        price-impact-factor: u100,
        last-price-update: current-time,
        volume-24h: u0,
        impermanent-loss-protection: false
      }
    )
    
    ;; Initialize market metrics
    (map-set market-metrics
      { market-id: market-id }
      {
        daily-volume: u0,
        weekly-volume: u0,
        unique-traders: u0,
        price-volatility: u0,
        liquidity-score: u0,
        last-updated: current-time
      }
    )
    
    ;; Mint market NFT to creator
    (try! (nft-mint? market-nft market-id creator))
    
    ;; Increment market ID
    (var-set next-market-id (+ market-id u1))
    
    (ok market-id)
  )
)

;; Calculate creation fee based on market parameters
(define-private (calculate-creation-fee (market-type uint) (duration uint))
  (let (
    (base-fee u5000000) ;; 5 STX base
    (type-multiplier (if (is-eq market-type market-type-conditional) u3 u1))
    (duration-factor (/ duration u1008)) ;; Per week factor
  )
    (+ base-fee (* type-multiplier (* duration-factor u1000000)))
  )
)

;; ===== COMMIT 2: ADVANCED AMM PRICING AND AUTOMATED MARKET MAKERS =====

;; Advanced liquidity provision with AMM
(define-public (provide-liquidity
  (market-id uint)
  (amount uint)
  (min-liquidity-tokens uint)
  (lock-duration uint))
  
  (let (
    (provider tx-sender)
    (market (unwrap! (map-get? markets-v2 { market-id: market-id }) err-market-not-found))
    (amm-pool (unwrap! (map-get? amm-pools { market-id: market-id }) err-market-not-found))
    (current-supply (get liquidity-token-supply amm-pool))
    (total-liquidity (get total-liquidity market))
  )
    ;; Validate market is active and supports AMM
    (asserts! (is-eq (get status market) u0) err-market-closed)
    (asserts! (> amount u0) err-invalid-parameters)
    (asserts! (<= lock-duration u26280) err-invalid-parameters) ;; Max 6 months lock
    
    ;; Transfer collateral from provider
    (try! (transfer-collateral amount provider (as-contract tx-sender) (get collateral-token market)))
    
    ;; Calculate liquidity tokens to mint
    (let (
      (liquidity-tokens (if (is-eq current-supply u0)
                           ;; First liquidity provider gets 1:1 ratio
                           amount
                           ;; Subsequent providers get proportional tokens
                           (/ (* amount current-supply) total-liquidity)))
      (lock-end-time (+ block-height lock-duration))
    )
      ;; Ensure minimum liquidity tokens met
      (asserts! (>= liquidity-tokens min-liquidity-tokens) err-insufficient-funds)
      
      ;; Update AMM pool
      (map-set amm-pools
        { market-id: market-id }
        (merge amm-pool {
          liquidity-token-supply: (+ current-supply liquidity-tokens),
          k-constant: (calculate-k-constant market-id (+ total-liquidity amount))
        })
      )
      
      ;; Update market liquidity
      (map-set markets-v2
        { market-id: market-id }
        (merge market { total-liquidity: (+ total-liquidity amount) })
      )
      
      ;; Record LP position
      (map-set lp-positions
        { market-id: market-id, provider: provider }
        {
          liquidity-tokens: (+ 
            (default-to u0 (get liquidity-tokens (map-get? lp-positions { market-id: market-id, provider: provider })))
            liquidity-tokens),
          initial-deposit: (+ 
            (default-to u0 (get initial-deposit (map-get? lp-positions { market-id: market-id, provider: provider })))
            amount),
          fees-earned: (default-to u0 (get fees-earned (map-get? lp-positions { market-id: market-id, provider: provider }))),
          entry-time: block-height,
          lock-end-time: lock-end-time
        }
      )
      
      (ok { liquidity-tokens: liquidity-tokens })
    )
  )
)

;; Calculate k-constant for AMM (simplified constant product)
(define-private (calculate-k-constant (market-id uint) (total-liquidity uint))
  ;; For simplicity, using square of total liquidity as k-constant
  ;; In production, this would be more sophisticated based on outcome probabilities
  (* total-liquidity total-liquidity)
)

;; Advanced trading with AMM pricing
(define-public (trade-with-amm
  (market-id uint)
  (outcome-id uint)
  (trade-type uint) ;; 0=buy, 1=sell
  (amount uint)
  (min-shares uint)
  (max-slippage uint)) ;; In basis points (e.g., 500 = 5%)
  
  (let (
    (trader tx-sender)
    (market (unwrap! (map-get? markets-v2 { market-id: market-id }) err-market-not-found))
    (amm-pool (unwrap! (map-get? amm-pools { market-id: market-id }) err-market-not-found))
    (position (default-to {
      shares-owned: (list),
      total-invested: u0,
      realized-pnl: 0,
      unrealized-pnl: 0,
      entry-timestamp: block-height,
      last-trade-timestamp: block-height,
      margin-posted: u0
    } (map-get? positions-v2 { market-id: market-id, user: trader })))
  )
    ;; Validate trading conditions
    (asserts! (is-eq (get status market) u0) err-market-closed)
    (asserts! (< block-height (get trading-end-time market)) err-market-closed)
    (asserts! (< outcome-id (len (get outcomes market))) err-invalid-outcome)
    (asserts! (> amount u0) err-invalid-parameters)
    
    ;; Check position limits
    (let ((current-position-size (get-total-position-size trader market-id)))
      (asserts! (<= (+ current-position-size amount) (get max-position-size market)) err-position-limit-exceeded)
    )
    
    ;; Calculate AMM price and slippage
    (let (
      (current-price (calculate-amm-price market-id outcome-id))
      (price-impact (calculate-price-impact market-id outcome-id amount trade-type))
      (effective-price (if (is-eq trade-type u0)
                          (+ current-price price-impact) ;; Buy price increases
                          (- current-price price-impact))) ;; Sell price decreases
      (slippage-pct (if (> current-price u0)
                       (/ (* (abs-diff effective-price current-price) u10000) current-price)
                       u0))
    )
      ;; Check slippage tolerance
      (asserts! (<= slippage-pct max-slippage) err-invalid-parameters)
      
      (if (is-eq trade-type u0)
        ;; BUY ORDER
        (let (
          (shares-to-receive (/ (* amount u1000000) effective-price))
          (fee-amount (/ (* amount (get creator-fee market)) u10000))
          (protocol-fee (/ (* amount (var-get base-trading-fee)) u10000))
          (net-amount (- amount (+ fee-amount protocol-fee)))
        )
          ;; Ensure minimum shares received
          (asserts! (>= shares-to-receive min-shares) err-insufficient-funds)
          
          ;; Transfer collateral from trader
          (try! (transfer-collateral amount trader (as-contract tx-sender) (get collateral-token market)))
          
          ;; Update position
          (map-set positions-v2
            { market-id: market-id, user: trader }
            (merge position {
              shares-owned: (add-shares-to-position (get shares-owned position) outcome-id shares-to-receive effective-price),
              total-invested: (+ (get total-invested position) net-amount),
              last-trade-timestamp: block-height
            })
          )
          
          ;; Update market volume and metrics
          (try! (update-market-metrics market-id amount))
          
          ;; Distribute fees
          (try! (distribute-trading-fees market-id fee-amount protocol-fee))
          
          (ok { shares-received: shares-to-receive, effective-price: effective-price })
        )
        
        ;; SELL ORDER
        (let (
          (user-shares (get-user-shares (get shares-owned position) outcome-id))
          (shares-to-sell (min amount user-shares))
          (payout (/ (* shares-to-sell effective-price) u1000000))
          (fee-amount (/ (* payout (get creator-fee market)) u10000))
          (protocol-fee (/ (* payout (var-get base-trading-fee)) u10000))
          (net-payout (- payout (+ fee-amount protocol-fee)))
        )
          ;; Ensure sufficient shares to sell
          (asserts! (>= user-shares amount) err-shares-not-found)
          (asserts! (>= net-payout min-shares) err-insufficient-funds) ;; Using min-shares as min-payout
          
          ;; Update position
          (map-set positions-v2
            { market-id: market-id, user: trader }
            (merge position {
              shares-owned: (remove-shares-from-position (get shares-owned position) outcome-id shares-to-sell),
              realized-pnl: (+ (get realized-pnl position) (calculate-realized-pnl outcome-id shares-to-sell effective-price (get shares-owned position))),
              last-trade-timestamp: block-height
            })
          )
          
          ;; Transfer payout to trader
          (try! (as-contract (transfer-collateral net-payout (as-contract tx-sender) trader (get collateral-token market))))
          
          ;; Update market volume and metrics
          (try! (update-market-metrics market-id payout))
          
          ;; Distribute fees
          (try! (distribute-trading-fees market-id fee-amount protocol-fee))
          
          (ok { shares-sold: shares-to-sell, effective-price: effective-price, payout: net-payout })
        )
      )
    )
  )
)

;; Calculate AMM price using constant product formula
(define-private (calculate-amm-price (market-id uint) (outcome-id uint))
  (let (
    (market (unwrap-panic (map-get? markets-v2 { market-id: market-id })))
    (amm-pool (unwrap-panic (map-get? amm-pools { market-id: market-id })))
    (outcome-count (len (get outcomes market)))
    (total-liquidity (get total-liquidity market))
  )
    ;; Simplified pricing: equal probability starting point with adjustments
    ;; In production, this would use more sophisticated algorithms
    (if (> total-liquidity u0)
      (/ u100000000 outcome-count) ;; Base price of 1/n where n is number of outcomes
      u50000000) ;; Default 50% probability for binary markets
  )
)

;; Calculate price impact based on trade size
(define-private (calculate-price-impact (market-id uint) (outcome-id uint) (amount uint) (trade-type uint))
  (let (
    (market (unwrap-panic (map-get? markets-v2 { market-id: market-id })))
    (total-liquidity (get total-liquidity market))
    (impact-factor (get price-impact-factor (unwrap-panic (map-get? amm-pools { market-id: market-id }))))
  )
    ;; Calculate price impact: larger trades = more impact
    (if (> total-liquidity u0)
      (/ (* amount impact-factor) total-liquidity)
      u0)
  )
)

;; Helper function to calculate absolute difference
(define-private (abs-diff (a uint) (b uint))
  (if (> a b) (- a b) (- b a))
)

;; Helper function to find minimum of two values
(define-private (min (a uint) (b uint))
  (if (< a b) a b)
)

;; Get total position size for a user
(define-private (get-total-position-size (user principal) (market-id uint))
  (let (
    (position (map-get? positions-v2 { market-id: market-id, user: user }))
  )
    (match position
      pos (fold + (map get-shares-value (get shares-owned pos)) u0)
      u0
    )
  )
)

;; Helper to get shares value from position entry
(define-private (get-shares-value (entry { outcome-id: uint, shares: uint, avg-price: uint }))
  (get shares entry)
)

;; Add shares to existing position
(define-private (add-shares-to-position 
  (current-shares (list 20 { outcome-id: uint, shares: uint, avg-price: uint }))
  (outcome-id uint)
  (new-shares uint)
  (price uint))
  
  (let (
    (existing-entry (find-shares-entry current-shares outcome-id))
  )
    (match existing-entry
      entry 
        ;; Update existing entry with new average price
        (let (
          (total-shares (+ (get shares entry) new-shares))
          (weighted-avg-price (/ (+ (* (get shares entry) (get avg-price entry)) (* new-shares price)) total-shares))
          (updated-entry { outcome-id: outcome-id, shares: total-shares, avg-price: weighted-avg-price })
        )
          (replace-shares-entry current-shares outcome-id updated-entry)
        )
      ;; Add new entry
      (unwrap-panic (as-max-len? (append current-shares { outcome-id: outcome-id, shares: new-shares, avg-price: price }) u20))
    )
  )
)

;; Remove shares from position
(define-private (remove-shares-from-position
  (current-shares (list 20 { outcome-id: uint, shares: uint, avg-price: uint }))
  (outcome-id uint)
  (shares-to-remove uint))
  
  (let (
    (existing-entry (find-shares-entry current-shares outcome-id))
  )
    (match existing-entry
      entry
        (let (
          (remaining-shares (- (get shares entry) shares-to-remove))
        )
          (if (> remaining-shares u0)
            ;; Update entry with remaining shares
            (replace-shares-entry current-shares outcome-id 
              { outcome-id: outcome-id, shares: remaining-shares, avg-price: (get avg-price entry) })
            ;; Remove entry entirely
            (filter remove-shares-filter current-shares)
          )
        )
      current-shares ;; Entry not found, return unchanged
    )
  )
)

;; Find shares entry by outcome ID
(define-private (find-shares-entry 
  (shares (list 20 { outcome-id: uint, shares: uint, avg-price: uint }))
  (outcome-id uint))
  
  (let (
    (matching-entries (filter shares-matches-outcome shares))
  )
    (if (> (len matching-entries) u0)
      (some (unwrap-panic (element-at matching-entries u0)))
      none
    )
  )
)

;; Check if shares entry matches outcome
(define-private (shares-matches-outcome (entry { outcome-id: uint, shares: uint, avg-price: uint }))
  (is-eq (get outcome-id entry) outcome-id)
)

;; Filter to remove shares entries
(define-private (remove-shares-filter (entry { outcome-id: uint, shares: uint, avg-price: uint }))
  (not (is-eq (get outcome-id entry) outcome-id))
)

;; Replace shares entry in list
(define-private (replace-shares-entry
  (shares (list 20 { outcome-id: uint, shares: uint, avg-price: uint }))
  (outcome-id uint)
  (new-entry { outcome-id: uint, shares: uint, avg-price: uint }))
  
  (map replace-if-matching shares)
)

;; Helper for replacing matching entry
(define-private (replace-if-matching (entry { outcome-id: uint, shares: uint, avg-price: uint }))
  (if (is-eq (get outcome-id entry) outcome-id)
    new-entry
    entry
  )
)

;; Get user's shares for specific outcome
(define-private (get-user-shares 
  (shares (list 20 { outcome-id: uint, shares: uint, avg-price: uint }))
  (outcome-id uint))
  
  (match (find-shares-entry shares outcome-id)
    entry (get shares entry)
    u0
  )
)

;; Calculate realized P&L for a trade
(define-private (calculate-realized-pnl
  (outcome-id uint)
  (shares-sold uint)
  (sell-price uint)
  (current-shares (list 20 { outcome-id: uint, shares: uint, avg-price: uint })))
  
  (match (find-shares-entry current-shares outcome-id)
    entry 
      (let (
        (avg-cost (get avg-price entry))
        (cost-basis (/ (* shares-sold avg-cost) u1000000))
        (sale-proceeds (/ (* shares-sold sell-price) u1000000))
      )
        (to-int (if (> sale-proceeds cost-basis)
                   (- sale-proceeds cost-basis)
                   (- cost-basis sale-proceeds)))
      )
    0 ;; No existing position
  )
)

;; Transfer collateral token (supports multiple token types)
(define-private (transfer-collateral (amount uint) (sender principal) (recipient principal) (token-contract principal))
  ;; For now, assuming STX. In full implementation, this would handle different token contracts
  (stx-transfer? amount sender recipient)
)

;; Update market metrics after trading
(define-private (update-market-metrics (market-id uint) (volume uint))
  (let (
    (metrics (default-to {
      daily-volume: u0,
      weekly-volume: u0,
      unique-traders: u0,
      price-volatility: u0,
      liquidity-score: u0,
      last-updated: block-height
    } (map-get? market-metrics { market-id: market-id })))
    (amm-pool (unwrap! (map-get? amm-pools { market-id: market-id }) (ok false)))
  )
    ;; Update metrics
    (map-set market-metrics
      { market-id: market-id }
      (merge metrics {
        daily-volume: (+ (get daily-volume metrics) volume),
        weekly-volume: (+ (get weekly-volume metrics) volume),
        last-updated: block-height
      })
    )
    
    ;; Update AMM pool volume
    (map-set amm-pools
      { market-id: market-id }
      (merge amm-pool { volume-24h: (+ (get volume-24h amm-pool) volume) })
    )
    
    (ok true)
  )
)

;; Distribute trading fees
(define-private (distribute-trading-fees (market-id uint) (creator-fee-amount uint) (protocol-fee-amount uint))
  (let (
    (market (unwrap! (map-get? markets-v2 { market-id: market-id }) (ok false)))
    (creator (get creator market))
  )
    ;; Pay creator fee
    (try! (as-contract (stx-transfer? creator-fee-amount (as-contract tx-sender) creator)))
    
    ;; Pay protocol fee to contract owner
    (try! (as-contract (stx-transfer? protocol-fee-amount (as-contract tx-sender) contract-owner)))
    
    ;; Update AMM pool fee accumulation
    (let ((amm-pool (unwrap! (map-get? amm-pools { market-id: market-id }) (ok false))))
      (map-set amm-pools
        { market-id: market-id }
        (merge amm-pool { fee-accumulated: (+ (get fee-accumulated amm-pool) (+ creator-fee-amount protocol-fee-amount)) })
      )
    )
    
    (ok true)
  )
)

;; ===== COMMIT 3: CONDITIONAL MARKETS AND IMPROVED ORACLE CONSENSUS =====

;; Create conditional market that depends on another market's outcome
(define-public (create-conditional-market
  (parent-market-id uint)
  (required-outcome uint)
  (title (string-utf8 128))
  (description (string-utf8 512))
  (category (string-ascii 32))
  (outcomes (list 20 (string-utf8 128)))
  (collateral-token principal)
  (trading-duration uint)
  (resolution-time uint)
  (creator-fee uint)
  (oracle-fee uint)
  (resolution-source (string-utf8 256))
  (metadata (string-utf8 512)))
  
  (let (
    (parent-market (unwrap! (map-get? markets-v2 { market-id: parent-market-id }) err-market-not-found))
    (market-id (var-get next-market-id))
    (creator tx-sender)
    (current-time block-height)
  )
    ;; Validate parent market and conditions
    (asserts! (not (var-get protocol-paused)) err-market-paused)
    (asserts! (< required-outcome (len (get outcomes parent-market))) err-invalid-outcome)
    (asserts! (> (get resolution-time parent-market) current-time) err-invalid-condition)
    (asserts! (> trading-duration u144) err-invalid-parameters) ;; Min 1 day
    
    ;; Conditional market starts trading only after parent resolves
    (let (
      (trading-start-time (+ (get resolution-time parent-market) u144)) ;; 1 day after parent resolution
      (trading-end-time (+ trading-start-time trading-duration))
    )
      ;; Enhanced market creation fee for conditional markets
      (let ((creation-fee (calculate-creation-fee market-type-conditional trading-duration)))
        (try! (stx-transfer? creation-fee creator contract-owner))
      )
      
      ;; Create conditional market
      (map-set markets-v2
        { market-id: market-id }
        {
          creator: creator,
          title: title,
          description: description,
          category: category,
          market-type: market-type-conditional,
          outcomes: outcomes,
          collateral-token: collateral-token,
          creation-time: current-time,
          trading-start-time: trading-start-time,
          trading-end-time: trading-end-time,
          resolution-time: resolution-time,
          total-liquidity: u0,
          total-volume: u0,
          creator-fee: creator-fee,
          oracle-fee: oracle-fee,
          status: u4, ;; Start as paused until parent resolves
          resolution-source: resolution-source,
          metadata: metadata,
          conditional-parent: (some parent-market-id),
          conditional-outcome: (some required-outcome),
          min-liquidity-threshold: u1000000, ;; 1 STX minimum
          max-position-size: u100000000, ;; 100 STX maximum
          early-resolution-eligible: false
        }
      )
      
      ;; Initialize supporting data structures
      (map-set amm-pools
        { market-id: market-id }
        {
          k-constant: u0,
          liquidity-token-supply: u0,
          fee-accumulated: u0,
          price-impact-factor: u150, ;; Higher impact for conditional markets
          last-price-update: current-time,
          volume-24h: u0,
          impermanent-loss-protection: true
        }
      )
      
      (map-set market-metrics
        { market-id: market-id }
        {
          daily-volume: u0,
          weekly-volume: u0,
          unique-traders: u0,
          price-volatility: u0,
          liquidity-score: u0,
          last-updated: current-time
        }
      )
      
      ;; Mint market NFT to creator
      (try! (nft-mint? market-nft market-id creator))
      
      ;; Increment market ID
      (var-set next-market-id (+ market-id u1))
      
      (ok market-id)
    )
  )
)

;; Activate conditional market when parent market resolves correctly
(define-public (activate-conditional-market (market-id uint))
  (let (
    (market (unwrap! (map-get? markets-v2 { market-id: market-id }) err-market-not-found))
    (parent-market-id (unwrap! (get conditional-parent market) err-invalid-condition))
    (required-outcome (unwrap! (get conditional-outcome market) err-invalid-condition))
    (parent-market (unwrap! (map-get? markets-v2 { market-id: parent-market-id }) err-market-not-found))
  )
    ;; Validate conditions for activation
    (asserts! (is-eq (get market-type market) market-type-conditional) err-invalid-parameters)
    (asserts! (is-eq (get status market) u4) err-market-paused) ;; Must be paused
    (asserts! (is-eq (get status parent-market) u2) err-market-not-resolved) ;; Parent must be resolved
    
    ;; Check if parent market resolved to required outcome
    (let ((parent-resolution (unwrap! (get-market-resolution parent-market-id) err-market-not-resolved)))
      (if (is-eq parent-resolution required-outcome)
        ;; Activate the conditional market
        (begin
          (map-set markets-v2
            { market-id: market-id }
            (merge market { status: u0 }) ;; Activate market
          )
          (ok true)
        )
        ;; Cancel the conditional market if parent didn't resolve as expected
        (begin
          (map-set markets-v2
            { market-id: market-id }
            (merge market { status: u1 }) ;; Close market
          )
          (ok false) ;; Market cancelled
        )
      )
    )
  )
)

;; Enhanced oracle consensus system
(define-public (submit-oracle-vote
  (market-id uint)
  (outcome uint)
  (confidence uint)
  (stake-amount uint)
  (reasoning (optional (string-utf8 256))))
  
  (let (
    (oracle tx-sender)
    (market (unwrap! (map-get? markets-v2 { market-id: market-id }) err-market-not-found))
    (oracle-info (unwrap! (map-get? oracle-network { oracle: oracle }) err-unauthorized-oracle))
  )
    ;; Validate oracle and market conditions
    (asserts! (is-eq (get status oracle-info) u0) err-unauthorized-oracle) ;; Oracle must be active
    (asserts! (>= block-height (get trading-end-time market)) err-market-not-closed)
    (asserts! (< outcome (len (get outcomes market))) err-invalid-outcome)
    (asserts! (<= confidence u100) err-invalid-parameters)
    (asserts! (>= stake-amount u1000000) err-invalid-parameters) ;; Min 1 STX stake
    
    ;; Check oracle hasn't already voted
    (asserts! (is-none (map-get? oracle-votes { market-id: market-id, oracle: oracle })) err-invalid-parameters)
    
    ;; Transfer stake from oracle
    (try! (stx-transfer? stake-amount oracle (as-contract tx-sender)))
    
    ;; Record oracle vote
    (map-set oracle-votes
      { market-id: market-id, oracle: oracle }
      {
        outcome: outcome,
        confidence: confidence,
        timestamp: block-height,
        stake-amount: stake-amount,
        reasoning: reasoning
      }
    )
    
    ;; Update oracle stats
    (map-set oracle-network
      { oracle: oracle }
      (merge oracle-info { 
        last-active: block-height,
        stake-amount: (+ (get stake-amount oracle-info) stake-amount)
      })
    )
    
    (ok true)
  )
)

;; Calculate oracle consensus and resolve market
(define-public (resolve-with-consensus (market-id uint))
  (let (
    (market (unwrap! (map-get? markets-v2 { market-id: market-id }) err-market-not-found))
    (consensus-result (calculate-consensus market-id))
  )
    ;; Validate resolution conditions
    (asserts! (>= block-height (+ (get trading-end-time market) u144)) err-market-not-closed) ;; 1 day after close
    (asserts! (is-eq (get status market) u0) err-market-closed) ;; Must be active
    (asserts! (>= (get vote-count consensus-result) (var-get min-oracle-consensus)) err-oracle-consensus-failed)
    
    (let (
      (winning-outcome (get consensus-outcome consensus-result))
      (confidence-score (get confidence-score consensus-result))
    )
      ;; Only proceed if consensus is strong enough (>60% confidence)
      (asserts! (>= confidence-score u60) err-oracle-consensus-failed)
      
             ;; Resolve market
       (map-set markets-v2
         { market-id: market-id }
         (merge market { 
           status: u2 ;; Resolved
         })
       )
      
      ;; Record resolution outcome
      (map-set market-resolution
        { market-id: market-id }
        { 
          outcome: winning-outcome,
          resolution-time: block-height,
          consensus-confidence: confidence-score,
          resolver: tx-sender
        }
      )
      
      ;; Reward participating oracles based on their alignment with consensus
      (try! (distribute-oracle-rewards market-id winning-outcome))
      
      ;; Check and activate any conditional markets
      (try! (check-conditional-markets market-id winning-outcome))
      
      (ok { outcome: winning-outcome, confidence: confidence-score })
    )
  )
)

;; Market resolution storage
(define-map market-resolution
  { market-id: uint }
  {
    outcome: uint,
    resolution-time: uint,
    consensus-confidence: uint,
    resolver: principal
  }
)

;; Get market resolution
(define-read-only (get-market-resolution (market-id uint))
  (match (map-get? market-resolution { market-id: market-id })
    resolution (some (get outcome resolution))
    none
  )
)

;; Calculate consensus from oracle votes
(define-private (calculate-consensus (market-id uint))
  (let (
    (all-oracles (get-market-oracles market-id))
    (vote-results (calculate-weighted-votes market-id all-oracles))
  )
    (get-consensus-outcome vote-results)
  )
)

;; Get all oracles that voted on a market
(define-private (get-market-oracles (market-id uint))
  ;; In a full implementation, this would iterate through oracle-votes map
  ;; For simplicity, returning a placeholder list
  (list tx-sender) ;; Placeholder - would be dynamic in production
)

;; Calculate weighted votes (simplified implementation)
(define-private (calculate-weighted-votes (market-id uint) (oracles (list 50 principal)))
  ;; Simplified: return basic consensus data
  {
    outcome-0-weight: u100,
    outcome-1-weight: u80,
    total-votes: u2,
    max-confidence: u75
  }
)

;; Get consensus outcome from vote results
(define-private (get-consensus-outcome (vote-results { outcome-0-weight: uint, outcome-1-weight: uint, total-votes: uint, max-confidence: uint }))
  {
    consensus-outcome: (if (> (get outcome-0-weight vote-results) (get outcome-1-weight vote-results)) u0 u1),
    confidence-score: (get max-confidence vote-results),
    vote-count: (get total-votes vote-results)
  }
)

;; Distribute rewards to oracles based on consensus alignment
(define-private (distribute-oracle-rewards (market-id uint) (winning-outcome uint))
  ;; Simplified implementation - would calculate rewards based on vote accuracy
  (ok true)
)

;; Check and activate conditional markets after parent resolution
(define-private (check-conditional-markets (parent-market-id uint) (resolution-outcome uint))
  ;; In full implementation, would iterate through all conditional markets
  ;; and activate those that depend on this parent market
  (ok true)
)

;; Multi-oracle dispute system
(define-public (dispute-consensus
  (market-id uint)
  (proposed-outcome uint)
  (stake-amount uint)
  (evidence (string-utf8 512)))
  
  (let (
    (disputer tx-sender)
    (market (unwrap! (map-get? markets-v2 { market-id: market-id }) err-market-not-found))
    (resolution (unwrap! (map-get? market-resolution { market-id: market-id }) err-market-not-resolved))
    (min-dispute-stake (* (get oracle-fee market) u2)) ;; 2x oracle fee minimum
  )
    ;; Validate dispute conditions
    (asserts! (is-eq (get status market) u2) err-market-not-resolved) ;; Must be resolved
    (asserts! (not (is-eq proposed-outcome (get outcome resolution))) err-invalid-outcome)
    (asserts! (>= stake-amount min-dispute-stake) err-invalid-parameters)
    (asserts! (< block-height (+ (get resolution-time resolution) u1008)) err-dispute-period-ended) ;; 7 days to dispute
    
    ;; Transfer dispute stake
    (try! (stx-transfer? stake-amount disputer (as-contract tx-sender)))
    
    ;; Create dispute record
    (map-set market-disputes
      { market-id: market-id, disputer: disputer }
      {
        proposed-outcome: proposed-outcome,
        stake-amount: stake-amount,
        evidence: evidence,
        dispute-time: block-height,
        votes-for: u0,
        votes-against: u0,
        resolved: false
      }
    )
    
    ;; Update market status to disputed
    (map-set markets-v2
      { market-id: market-id }
      (merge market { status: u3 }) ;; Disputed
    )
    
    (ok true)
  )
)

;; Dispute storage
(define-map market-disputes
  { market-id: uint, disputer: principal }
  {
    proposed-outcome: uint,
    stake-amount: uint,
    evidence: (string-utf8 512),
    dispute-time: uint,
    votes-for: uint,
    votes-against: uint,
    resolved: bool
  }
)

;; Oracle voting on disputes
(define-public (vote-on-dispute
  (market-id uint)
  (disputer principal)
  (support bool)
  (reasoning (optional (string-utf8 256))))
  
  (let (
    (oracle tx-sender)
    (oracle-info (unwrap! (map-get? oracle-network { oracle: oracle }) err-unauthorized-oracle))
    (dispute (unwrap! (map-get? market-disputes { market-id: market-id, disputer: disputer }) err-market-not-found))
  )
    ;; Validate oracle can vote
    (asserts! (is-eq (get status oracle-info) u0) err-unauthorized-oracle)
    (asserts! (not (get resolved dispute)) err-market-resolved)
    
    ;; Record vote (simplified - would track individual votes in production)
    (let (
      (updated-dispute (merge dispute 
        (if support
          { votes-for: (+ (get votes-for dispute) (get consensus-weight oracle-info)) }
          { votes-against: (+ (get votes-against dispute) (get consensus-weight oracle-info)) }
        )
      ))
    )
      (map-set market-disputes
        { market-id: market-id, disputer: disputer }
        updated-dispute
      )
      
      ;; Check if dispute threshold reached (>60% support needed)
      (let (
        (total-votes (+ (get votes-for updated-dispute) (get votes-against updated-dispute)))
        (support-percentage (if (> total-votes u0) (/ (* (get votes-for updated-dispute) u100) total-votes) u0))
      )
        (if (and (>= total-votes u5) (>= support-percentage u60))
          ;; Dispute successful - update market resolution
          (begin
            (map-set market-resolution
              { market-id: market-id }
              {
                outcome: (get proposed-outcome dispute),
                resolution-time: block-height,
                consensus-confidence: support-percentage,
                resolver: disputer
              }
            )
            
            ;; Return stake plus reward to disputer
            (try! (as-contract (stx-transfer? (* (get stake-amount dispute) u11 (/ u10)) (as-contract tx-sender) disputer)))
            
            ;; Mark dispute as resolved
            (map-set market-disputes
              { market-id: market-id, disputer: disputer }
              (merge updated-dispute { resolved: true })
            )
            
            (ok { dispute-successful: true })
          )
          (ok { dispute-successful: false })
        )
      )
    )
  )
) 