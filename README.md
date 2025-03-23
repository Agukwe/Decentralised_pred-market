# Decentralized Prediction Market Platform

A Clarity-based smart contract platform for creating and participating in prediction markets on real-world events with trustless resolution and dispute mechanisms.

## Overview

This platform enables users to create prediction markets for any real-world event, participate in these markets by buying and selling outcome shares, and earn rewards for accurate predictions. The system incorporates oracles for result verification, includes robust dispute resolution mechanisms, and distributes fees to market creators, liquidity providers, and the protocol treasury.

## Features

### Market Creation and Customization
- Create markets with multiple possible outcomes (up to 10)
- Set custom parameters including:
  - Resolution timeframes
  - Trading fees
  - Minimum trade amounts
  - Dispute period lengths
- Category tagging for market organization
- Additional data fields for supplementary information

### Trading Mechanism
- Buy and sell outcome shares at dynamically adjusted prices
- Automated market maker ensures continuous liquidity
- Price discovery through market activity
- Fee structure that rewards market creators and sustains the protocol

### Liquidity Provision
- Users can add liquidity to earn from market activity
- Proportional fee distribution based on contribution
- Liquidity reclamation after market resolution

### Oracle Integration
- Authorized oracles report outcomes based on real-world events
- Oracle reputation system tracks reliability
- Oracles earn fees for accurate reporting

### Dispute Resolution
- Users can challenge oracle decisions by staking tokens
- Configurable dispute periods ensure time for proper verification
- Resolution process designed to protect against malicious actors

### Reward Distribution
- Winners claim proportional rewards from the total value locked
- Liquidity providers withdraw their share plus earnings
- Fee distribution to market creators and protocol treasury

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) for local development and testing
- [Stacks Wallet](https://www.hiro.so/wallet) for interacting with the deployed contract

### Installation
1. Clone the repository
2. Install dependencies with Clarinet
3. Test the contract with `clarinet test`

## Contract Functions

### Market Creation and Management

```clarity
;; Create a new prediction market
(create-market 
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
```

### Trading Functions

```clarity
;; Buy shares for a specific outcome
(buy-shares (market-id uint) (outcome-id uint) (amount uint))

;; Sell shares for a specific outcome
(sell-shares (market-id uint) (outcome-id uint) (shares-to-sell uint))
```

### Liquidity Functions

```clarity
;; Add liquidity to a market
(add-liquidity (market-id uint) (amount uint))

;; Remove liquidity after market resolution
(remove-liquidity (market-id uint))
```

### Oracle and Resolution Functions

```clarity
;; Resolve a market with the final outcome
(resolve-market (market-id uint) (outcome-id uint))

;; Dispute an oracle's resolution
(dispute-resolution (market-id uint) (proposed-outcome uint) (stake-amount uint))

;; Finalize a market after the dispute period
(finalize-market (market-id uint))
```

### Claiming and Withdrawals

```clarity
;; Claim winnings after market resolution
(claim-winnings (market-id uint))
```

### Governance Functions

```clarity
;; Add a new oracle
(add-oracle (oracle principal))

;; Update protocol parameters
(set-protocol-fee-percentage (new-percentage uint))
(set-min-dispute-stake (new-stake uint))
(set-default-dispute-period-length (new-length uint))
```

### Read-Only Functions

```clarity
;; Get market information
(get-market-info (market-id uint))

;; Get user position in a market
(get-user-position (market-id uint) (user principal))

;; Get market status
(get-market-status (market-id uint))
```

## Usage Examples

### Creating a Market

```clarity
(contract-call? .prediction-market create-market 
  "Will BTC reach $100k before the end of 2025?" 
  "Cryptocurrency" 
  (list "Yes" "No") 
  u730000 ;; Resolution time (block height)
  u720000 ;; Closing time (block height)
  u200 ;; 2% fee
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM ;; Oracle
  u5000000 ;; 0.05 STX oracle fee
  u1000000 ;; 0.01 STX minimum trade
  none) ;; No additional data
```

### Trading on a Market

```clarity
;; Buy shares for "Yes" outcome (Outcome ID 0)
(contract-call? .prediction-market buy-shares u1 u0 u5000000)

;; Sell shares for "Yes" outcome
(contract-call? .prediction-market sell-shares u1 u0 u10000)
```

### Adding Liquidity

```clarity
;; Add 100 STX liquidity to market #1
(contract-call? .prediction-market add-liquidity u1 u100000000)
```

### Resolving a Market (Oracle only)

```clarity
;; Resolve market #1 with "Yes" outcome (Outcome ID 0)
(contract-call? .prediction-market resolve-market u1 u0)
```

### Claiming Winnings

```clarity
;; Claim winnings after market resolution
(contract-call? .prediction-market claim-winnings u1)
```

## Market Lifecycle

1. **Market Creation**: A user creates a market by specifying parameters and outcomes
2. **Active Trading**: Users buy and sell outcome shares, adding/removing liquidity
3. **Market Closure**: Trading stops at the specified closing time
4. **Oracle Resolution**: Authorized oracle submits the outcome
5. **Dispute Period**: Users can challenge the oracle's decision by staking tokens
6. **Market Finalization**: After the dispute period, the market is finalized
7. **Reward Distribution**: Winners claim rewards, liquidity providers withdraw funds

## Risk Management

- The contract includes safeguards against market manipulation
- Disputes provide protection against malicious oracles
- Fee structures are designed to prevent exploits
- Market parameters are validated to ensure fairness

## Technical Details

The contract handles:
- Precise token accounting
- Price discovery through automated market makers
- Fee calculation and distribution
- Dispute resolution logic
- Liquidity pool management

## Governance

The contract owner can:
- Add/remove authorized oracles
- Update protocol fee percentages
- Set minimum dispute stake requirements
- Adjust default dispute period lengths
- Update the treasury address

## Future Improvements

- Integration with more oracle sources
- Advanced market types (scalar, categorical with more outcomes)
- Conditional markets
- Mobile-friendly UI
- Analytics dashboard for market trends

## Appendix

### Error Codes

```
err-owner-only (err u100)
err-not-authorized (err u101)
err-market-exists (err u102)
err-market-not-found (err u103)
...
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.