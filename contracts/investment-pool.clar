;; investment-pool
;; CoinFlow Investment Pool Manager - Community-driven DeFi investment pools
;; Allows users to create investment pools, stake STX, participate in governance, and earn yields

;; ========================================
;; CONSTANTS AND CONFIGURATION
;; ========================================

;; Contract Information
(define-constant CONTRACT-OWNER tx-sender)
(define-constant CONTRACT-VERSION "1.0.0")

;; Error Codes
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-NOT-FOUND (err u201))
(define-constant ERR-INVALID-AMOUNT (err u202))
(define-constant ERR-INVALID-PARAMETERS (err u203))
(define-constant ERR-INSUFFICIENT-FUNDS (err u204))
(define-constant ERR-POOL-CLOSED (err u205))
(define-constant ERR-POOL-EXISTS (err u206))
(define-constant ERR-MINIMUM-STAKE-NOT-MET (err u207))
(define-constant ERR-WITHDRAWAL-PERIOD-NOT-MET (err u208))
(define-constant ERR-PROPOSAL-EXISTS (err u209))
(define-constant ERR-VOTING-PERIOD-ENDED (err u210))
(define-constant ERR-ALREADY-VOTED (err u211))
(define-constant ERR-INSUFFICIENT-VOTING-POWER (err u212))
(define-constant ERR-PROPOSAL-NOT-PASSED (err u213))
(define-constant ERR-POOL-LIMIT-REACHED (err u214))

;; Pool Configuration
(define-constant MIN-STAKE-AMOUNT u1000000) ;; 1 STX minimum
(define-constant MAX-POOLS-PER-USER u10)
(define-constant WITHDRAWAL-LOCK-PERIOD u144) ;; ~24 hours in blocks
(define-constant VOTING-PERIOD u1008) ;; ~7 days in blocks
(define-constant MIN-VOTING-POWER u500000) ;; 0.5 STX minimum to vote
(define-constant PLATFORM-FEE-RATE u250) ;; 2.5% platform fee (basis points)
(define-constant MAX-PLATFORM-FEE u1000) ;; 10% max platform fee

;; Pool Types
(define-constant POOL-TYPE-CONSERVATIVE "conservative")
(define-constant POOL-TYPE-MODERATE "moderate")
(define-constant POOL-TYPE-AGGRESSIVE "aggressive")
(define-constant POOL-TYPE-EXPERIMENTAL "experimental")

;; Pool Status
(define-constant POOL-STATUS-ACTIVE u1)
(define-constant POOL-STATUS-PAUSED u2)
(define-constant POOL-STATUS-CLOSED u3)

;; Proposal Types
(define-constant PROPOSAL-TYPE-INVESTMENT "investment")
(define-constant PROPOSAL-TYPE-WITHDRAWAL "withdrawal")
(define-constant PROPOSAL-TYPE-FEE-CHANGE "fee_change")
(define-constant PROPOSAL-TYPE-POOL-CLOSURE "pool_closure")

;; ========================================
;; DATA VARIABLES
;; ========================================

;; Global Counters
(define-data-var total-pools uint u0)
(define-data-var total-proposals uint u0)
(define-data-var total-staked-amount uint u0)
(define-data-var platform-treasury uint u0)

;; Contract State
(define-data-var contract-paused bool false)
(define-data-var emergency-withdrawal-enabled bool false)

;; ========================================
;; DATA MAPS
;; ========================================

;; Investment Pools
(define-map pools
    {pool-id: uint}
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        pool-type: (string-ascii 20),
        creator: principal,
        total-staked: uint,
        participant-count: uint,
        min-stake: uint,
        max-stake: uint,
        fee-rate: uint,
        status: uint,
        created-at: uint,
        updated-at: uint,
        target-amount: uint,
        current-yield: uint,
        total-distributed: uint,
        governance-token-supply: uint
    })

;; User Stakes in Pools
(define-map stakes
    {pool-id: uint, user: principal}
    {
        amount: uint,
        staked-at: uint,
        last-reward-block: uint,
        governance-power: uint,
        pending-rewards: uint,
        total-earned: uint
    })

;; Pool Proposals
(define-map proposals
    {proposal-id: uint}
    {
        pool-id: uint,
        proposer: principal,
        proposal-type: (string-ascii 20),
        title: (string-ascii 100),
        description: (string-ascii 300),
        target-amount: uint,
        target-address: (optional principal),
        votes-for: uint,
        votes-against: uint,
        voting-ends-at: uint,
        status: uint,
        created-at: uint,
        executed-at: (optional uint)
    })

;; User Votes
(define-map votes
    {proposal-id: uint, voter: principal}
    {
        voting-power: uint,
        vote-type: bool, ;; true = for, false = against
        voted-at: uint
    })

;; User Pool Participation
(define-map user-pools
    {user: principal}
    {
        pool-count: uint,
        total-staked: uint,
        total-earned: uint,
        active-proposals: uint
    })

;; Pool Performance Metrics
(define-map pool-metrics
    {pool-id: uint, period: (string-ascii 20)}
    {
        start-amount: uint,
        end-amount: uint,
        yield-rate: uint,
        participant-count: uint,
        recorded-at: uint
    })

;; ========================================
;; PRIVATE HELPER FUNCTIONS
;; ========================================

;; Get current block height
(define-private (get-current-block)
    block-height)

;; Validate amount is within reasonable bounds
(define-private (is-valid-amount (amount uint))
    (and (>= amount MIN-STAKE-AMOUNT)
         (<= amount u1000000000000))) ;; 1 million STX max

;; Validate string length
(define-private (is-valid-string-length (str (string-ascii 300)) (max-length uint))
    (and (> (len str) u0)
         (<= (len str) max-length)))

;; Validate pool type
(define-private (is-valid-pool-type (pool-type (string-ascii 20)))
    (or (is-eq pool-type POOL-TYPE-CONSERVATIVE)
        (is-eq pool-type POOL-TYPE-MODERATE)
        (is-eq pool-type POOL-TYPE-AGGRESSIVE)
        (is-eq pool-type POOL-TYPE-EXPERIMENTAL)))

;; Calculate governance power based on stake amount and duration
(define-private (calculate-governance-power (amount uint) (staked-duration uint))
    (+ amount (/ (* amount staked-duration) u10000)))

;; Check if user can create more pools
(define-private (can-create-pool (user principal))
    (let ((user-data (default-to 
                        {pool-count: u0, total-staked: u0, total-earned: u0, active-proposals: u0}
                        (map-get? user-pools {user: user}))))
        (< (get pool-count user-data) MAX-POOLS-PER-USER)))

;; Calculate platform fee
(define-private (calculate-platform-fee (amount uint) (fee-rate uint))
    (/ (* amount fee-rate) u10000))

;; Get next pool ID
(define-private (get-next-pool-id)
    (+ (var-get total-pools) u1))

;; Get next proposal ID
(define-private (get-next-proposal-id)
    (+ (var-get total-proposals) u1))

;; ========================================
;; POOL MANAGEMENT FUNCTIONS
;; ========================================

;; Create a new investment pool
(define-public (create-pool 
    (name (string-ascii 50))
    (description (string-ascii 200))
    (pool-type (string-ascii 20))
    (min-stake uint)
    (max-stake uint)
    (target-amount uint)
    (fee-rate uint))
    (let ((creator tx-sender)
          (pool-id (get-next-pool-id))
          (current-block (get-current-block)))
        
        ;; Validate inputs
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts! (is-valid-string-length name u50) ERR-INVALID-PARAMETERS)
        (asserts! (is-valid-string-length description u200) ERR-INVALID-PARAMETERS)
        (asserts! (is-valid-pool-type pool-type) ERR-INVALID-PARAMETERS)
        (asserts! (>= min-stake MIN-STAKE-AMOUNT) ERR-INVALID-PARAMETERS)
        (asserts! (<= max-stake u100000000000) ERR-INVALID-PARAMETERS) ;; 100k STX max
        (asserts! (> max-stake min-stake) ERR-INVALID-PARAMETERS)
        (asserts! (<= fee-rate MAX-PLATFORM-FEE) ERR-INVALID-PARAMETERS)
        (asserts! (can-create-pool creator) ERR-POOL-LIMIT-REACHED)

        ;; Create pool
        (map-set pools
            {pool-id: pool-id}
            {
                name: name,
                description: description,
                pool-type: pool-type,
                creator: creator,
                total-staked: u0,
                participant-count: u0,
                min-stake: min-stake,
                max-stake: max-stake,
                fee-rate: fee-rate,
                status: POOL-STATUS-ACTIVE,
                created-at: current-block,
                updated-at: current-block,
                target-amount: target-amount,
                current-yield: u0,
                total-distributed: u0,
                governance-token-supply: u0
            })

        ;; Update creator's pool count
        (let ((user-data (default-to 
                            {pool-count: u0, total-staked: u0, total-earned: u0, active-proposals: u0}
                            (map-get? user-pools {user: creator}))))
            (map-set user-pools
                {user: creator}
                (merge user-data {pool-count: (+ (get pool-count user-data) u1)})))

        ;; Update global counter
        (var-set total-pools pool-id)

        (ok pool-id)))

;; Stake STX in a pool
(define-public (stake-in-pool (pool-id uint) (amount uint))
    (let ((user tx-sender)
          (current-block (get-current-block)))
        
        ;; Get pool data
        (match (map-get? pools {pool-id: pool-id})
            pool-data
            (begin
                ;; Validate stake
                (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
                (asserts! (is-eq (get status pool-data) POOL-STATUS-ACTIVE) ERR-POOL-CLOSED)
                (asserts! (>= amount (get min-stake pool-data)) ERR-MINIMUM-STAKE-NOT-MET)
                (asserts! (<= amount (get max-stake pool-data)) ERR-INVALID-AMOUNT)

                ;; Transfer STX to contract
                (try! (stx-transfer? amount user (as-contract tx-sender)))

                ;; Get existing stake or create new one
                (let ((existing-stake (map-get? stakes {pool-id: pool-id, user: user}))
                      (new-amount (if (is-some existing-stake)
                                    (+ amount (get amount (unwrap-panic existing-stake)))
                                    amount))
                      (governance-power (calculate-governance-power new-amount u0)))

                    ;; Update or create stake
                    (map-set stakes
                        {pool-id: pool-id, user: user}
                        {
                            amount: new-amount,
                            staked-at: current-block,
                            last-reward-block: current-block,
                            governance-power: governance-power,
                            pending-rewards: u0,
                            total-earned: (if (is-some existing-stake) 
                                            (get total-earned (unwrap-panic existing-stake))
                                            u0)
                        })

                    ;; Update pool data
                    (map-set pools
                        {pool-id: pool-id}
                        (merge pool-data {
                            total-staked: (+ (get total-staked pool-data) amount),
                            participant-count: (if (is-none existing-stake)
                                                 (+ (get participant-count pool-data) u1)
                                                 (get participant-count pool-data)),
                            updated-at: current-block,
                            governance-token-supply: (+ (get governance-token-supply pool-data) governance-power)
                        }))

                    ;; Update user pools
                    (let ((user-data (default-to 
                                        {pool-count: u0, total-staked: u0, total-earned: u0, active-proposals: u0}
                                        (map-get? user-pools {user: user}))))
                        (map-set user-pools
                            {user: user}
                            (merge user-data {
                                total-staked: (+ (get total-staked user-data) amount),
                                pool-count: (if (is-none existing-stake)
                                              (+ (get pool-count user-data) u1)
                                              (get pool-count user-data))
                            })))

                    ;; Update global total
                    (var-set total-staked-amount (+ (var-get total-staked-amount) amount))

                    (ok new-amount)))
            ERR-NOT-FOUND)))

;; ========================================
;; GOVERNANCE FUNCTIONS
;; ========================================

;; Create a proposal
(define-public (create-proposal
    (pool-id uint)
    (proposal-type (string-ascii 20))
    (title (string-ascii 100))
    (description (string-ascii 300))
    (target-amount uint)
    (target-address (optional principal)))
    (let ((proposer tx-sender)
          (proposal-id (get-next-proposal-id))
          (current-block (get-current-block)))

        ;; Check if user has voting power in this pool
        (match (map-get? stakes {pool-id: pool-id, user: proposer})
            stake-data
            (begin
                (asserts! (>= (get governance-power stake-data) MIN-VOTING-POWER) ERR-INSUFFICIENT-VOTING-POWER)
                
                ;; Validate inputs
                (asserts! (is-valid-string-length title u100) ERR-INVALID-PARAMETERS)
                (asserts! (is-valid-string-length description u300) ERR-INVALID-PARAMETERS)

                ;; Create proposal
                (map-set proposals
                    {proposal-id: proposal-id}
                    {
                        pool-id: pool-id,
                        proposer: proposer,
                        proposal-type: proposal-type,
                        title: title,
                        description: description,
                        target-amount: target-amount,
                        target-address: target-address,
                        votes-for: u0,
                        votes-against: u0,
                        voting-ends-at: (+ current-block VOTING-PERIOD),
                        status: u1, ;; Active
                        created-at: current-block,
                        executed-at: none
                    })

                (var-set total-proposals proposal-id)
                (ok proposal-id))
            ERR-INSUFFICIENT-VOTING-POWER)))

;; Vote on a proposal
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
    (let ((voter tx-sender)
          (current-block (get-current-block)))

        ;; Get proposal data
        (match (map-get? proposals {proposal-id: proposal-id})
            proposal-data
            (begin
                ;; Check voting period
                (asserts! (< current-block (get voting-ends-at proposal-data)) ERR-VOTING-PERIOD-ENDED)
                
                ;; Check if already voted
                (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: voter})) ERR-ALREADY-VOTED)

                ;; Get voter's stake in the pool
                (match (map-get? stakes {pool-id: (get pool-id proposal-data), user: voter})
                    stake-data
                    (let ((voting-power (get governance-power stake-data)))
                        (asserts! (>= voting-power MIN-VOTING-POWER) ERR-INSUFFICIENT-VOTING-POWER)

                        ;; Record vote
                        (map-set votes
                            {proposal-id: proposal-id, voter: voter}
                            {
                                voting-power: voting-power,
                                vote-type: vote-for,
                                voted-at: current-block
                            })

                        ;; Update proposal vote counts
                        (map-set proposals
                            {proposal-id: proposal-id}
                            (merge proposal-data {
                                votes-for: (if vote-for
                                             (+ (get votes-for proposal-data) voting-power)
                                             (get votes-for proposal-data)),
                                votes-against: (if vote-for
                                                 (get votes-against proposal-data)
                                                 (+ (get votes-against proposal-data) voting-power))
                            }))

                        (ok voting-power))
                    ERR-INSUFFICIENT-VOTING-POWER))
            ERR-NOT-FOUND)))

;; ========================================
;; READ-ONLY FUNCTIONS
;; ========================================

;; Get pool information
(define-read-only (get-pool (pool-id uint))
    (map-get? pools {pool-id: pool-id}))

;; Get user stake in pool
(define-read-only (get-stake (pool-id uint) (user principal))
    (map-get? stakes {pool-id: pool-id, user: user}))

;; Get proposal information
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals {proposal-id: proposal-id}))

;; Get user's vote on proposal
(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes {proposal-id: proposal-id, voter: voter}))

;; Get user pool summary
(define-read-only (get-user-pools (user principal))
    (map-get? user-pools {user: user}))

;; Get contract stats
(define-read-only (get-contract-stats)
    (ok {
        total-pools: (var-get total-pools),
        total-proposals: (var-get total-proposals),
        total-staked: (var-get total-staked-amount),
        platform-treasury: (var-get platform-treasury),
        contract-paused: (var-get contract-paused)
    }))

;; ========================================
;; ADMIN FUNCTIONS
;; ========================================

;; Pause/unpause contract
(define-public (set-contract-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (var-set contract-paused paused)
        (ok paused)))

;; Emergency withdrawal (admin only)
(define-public (emergency-withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (var-get emergency-withdrawal-enabled) ERR-UNAUTHORIZED)
        (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
        (ok amount)))

;; Enable emergency withdrawal
(define-public (enable-emergency-withdrawal)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (var-set emergency-withdrawal-enabled true)
        (ok true)))