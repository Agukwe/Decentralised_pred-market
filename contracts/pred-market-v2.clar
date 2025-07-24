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
        default-outcomes: (list "Yes" "No"),
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
        default-outcomes: (list "Below $X" "$X to $Y" "Above $Y"),
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
        default-outcomes: (list "Team A Wins" "Draw" "Team B Wins"),
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