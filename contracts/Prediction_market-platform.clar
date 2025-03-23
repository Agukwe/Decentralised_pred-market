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
