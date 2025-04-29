;; Financial Oracle Smart Contract
;; Delivers real-time financial data, currency conversions, rate calculations, and detailed reporting

;; Response codes
(define-constant RESP-UNAUTHORIZED (err u100))
(define-constant RESP-INVALID-VALUE (err u101))
(define-constant RESP-RATE-UNAVAILABLE (err u102))
(define-constant RESP-BALANCE-TOO-LOW (err u103))
(define-constant RESP-RATE-OUT-OF-BOUNDS (err u104))
(define-constant RESP-UNSUPPORTED-CURRENCY (err u105))
(define-constant RESP-INVALID-ADJUSTMENT (err u106))
(define-constant RESP-REBATE-DENIED (err u107))
(define-constant RESP-INVALID-TIMEFRAME (err u108))
(define-constant RESP-TRANSFER-ERROR (err u109))

;; System variables
(define-data-var operator principal tx-sender)
(define-data-var baseline-threshold uint u100) ;; Minimum calculable amount in base currency

;; Forex data (scaled by 1e8)
(define-map forex-rates
    { currency-symbol: (string-ascii 10) }
    { rate-value: uint,
      last-updated: uint,
      is-active: bool }
)

;; Calculation tiers with graduated levels
(define-map calculation-tiers
    { calculation-type: (string-ascii 24) }
    {
        tier-structure: (list 10 {
            value-threshold: uint,
            rate-percentage: uint,
            tier-notes: (string-ascii 64)
        }),
        reference-currency: (string-ascii 10),
        tier-update-time: uint
    }
)

;; Adjustment factors configuration
(define-map adjustment-factors
    { adjustment-code: (string-ascii 10) }
    {
        adjustment-label: (string-ascii 64),
        max-adjustment-value: uint,
        adjustment-rate: uint,
        verification-required: bool
    }
)

;; User records with comprehensive tracking
(define-map user-profiles
    principal
    {
        total-fees-paid: uint,
        total-rebates-received: uint,
        latest-transaction: uint,
        user-segment: (string-ascii 24),
        applied-adjustments: (list 20 {
            adjustment-code: (string-ascii 10),
            adjustment-value: uint,
            adjustment-confirmed: bool
        }),
        activity-log: (list 50 {
            transaction-value: uint,
            timestamp: uint,
            transaction-currency: (string-ascii 10)
        })
    }
)

;; Read-only functions for data retrieval
(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles user)
)

(define-read-only (get-calculation-tier-info (calculation-type (string-ascii 24)))
    (map-get? calculation-tiers { calculation-type: calculation-type })
)

(define-read-only (get-forex-rate (currency-symbol (string-ascii 10)))
    (map-get? forex-rates { currency-symbol: currency-symbol })
)

(define-read-only (get-adjustment-info (adjustment-code (string-ascii 10)))
    (map-get? adjustment-factors { adjustment-code: adjustment-code })
)

;; Currency conversion utility
(define-read-only (convert-currency (amount uint) (from-currency (string-ascii 10)) (to-currency (string-ascii 10)))
    (let (
        (source-rate (unwrap! (get-forex-rate from-currency) RESP-UNSUPPORTED-CURRENCY))
        (target-rate (unwrap! (get-forex-rate to-currency) RESP-UNSUPPORTED-CURRENCY))
    )
        (ok (/ (* amount (get rate-value target-rate)) (get rate-value source-rate)))
    )
)

(define-read-only (calculate-tiered-rate (input-amount uint) (calculation-type (string-ascii 24)))
    (match (map-get? calculation-tiers { calculation-type: calculation-type })
        tier-data
        (let ((total-calculated u0))
            (ok (fold process-tier-calculation 
                (get tier-structure tier-data)
                { remaining-value: input-amount, cumulative-result: u0 })))
        RESP-RATE-UNAVAILABLE
    )
)

;; Helper for tiered calculation
(define-private (process-tier-calculation 
    (tier { value-threshold: uint, rate-percentage: uint, tier-notes: (string-ascii 64) })
    (calculation-state { remaining-value: uint, cumulative-result: uint }))
    (let (
        (applicable-amount (if (> (get remaining-value calculation-state) (get value-threshold tier))
            (- (get remaining-value calculation-state) (get value-threshold tier))
            u0))
        (tier-result (/ (* applicable-amount (get rate-percentage tier)) u100))
    )
        { 
            remaining-value: (get remaining-value calculation-state),
            cumulative-result: (+ (get cumulative-result calculation-state) tier-result)
        }
    )
)

;; Define helper function to update adjustment verification
(define-private (update-adjustment-status 
    (index uint) 
    (current-index uint) 
    (adjustment { adjustment-code: (string-ascii 10), adjustment-value: uint, adjustment-confirmed: bool })
    (target-index uint))
    (if (is-eq current-index target-index)
        ;; If this is the target index, return updated adjustment with confirmed status
        {
            adjustment-code: (get adjustment-code adjustment),
            adjustment-value: (get adjustment-value adjustment),
            adjustment-confirmed: true
        }
        ;; Otherwise return the original adjustment unchanged
        adjustment)
)

;; Administrative functions
(define-public (update-forex-rate (currency-symbol (string-ascii 10)) (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get operator)) RESP-UNAUTHORIZED)
        (ok (map-set forex-rates
            { currency-symbol: currency-symbol }
            { rate-value: new-rate,
              last-updated: block-height,
              is-active: true }
        ))
    )
)

(define-public (register-adjustment-type (adjustment-code (string-ascii 10)) (adjustment-label (string-ascii 64)) 
               (max-value uint) (adjustment-rate uint) (verification-required bool))
    (begin
        (asserts! (is-eq tx-sender (var-get operator)) RESP-UNAUTHORIZED)
        (asserts! (<= adjustment-rate u100) RESP-RATE-OUT-OF-BOUNDS)
        (ok (map-set adjustment-factors
            { adjustment-code: adjustment-code }
            { adjustment-label: adjustment-label,
              max-adjustment-value: max-value,
              adjustment-rate: adjustment-rate,
              verification-required: verification-required }
        ))
    )
)

(define-public (submit-adjustment-request (adjustment-code (string-ascii 10)) (adjustment-value uint))
    (let (
        (adjustment-details (unwrap! (get-adjustment-info adjustment-code) RESP-INVALID-ADJUSTMENT))
        (user-profile (default-to 
            {
                total-fees-paid: u0,
                total-rebates-received: u0,
                latest-transaction: u0,
                user-segment: "",
                applied-adjustments: (list ),
                activity-log: (list )
            }
            (get-user-profile tx-sender)))
    )
        (begin
            (asserts! (<= adjustment-value (get max-adjustment-value adjustment-details)) RESP-INVALID-VALUE)
            (ok (map-set user-profiles
                tx-sender
                {
                    total-fees-paid: (get total-fees-paid user-profile),
                    total-rebates-received: (get total-rebates-received user-profile),
                    latest-transaction: (get latest-transaction user-profile),
                    user-segment: (get user-segment user-profile),
                    applied-adjustments: (unwrap-panic (as-max-len? 
                        (append (get applied-adjustments user-profile)
                            {
                                adjustment-code: adjustment-code,
                                adjustment-value: adjustment-value,
                                adjustment-confirmed: (not (get verification-required adjustment-details))
                            })
                        u20)),
                    activity-log: (get activity-log user-profile)
                }
            ))
        )
    )
)

;; Modified approve-adjustment-request function
(define-public (approve-adjustment-request (user principal) (adjustment-index uint))
    (let (
        (user-profile (unwrap! (get-user-profile user) RESP-RATE-UNAVAILABLE))
        (current-adjustments (get applied-adjustments user-profile))
    )
        (begin
            (asserts! (is-eq tx-sender (var-get operator)) RESP-UNAUTHORIZED)
            (asserts! (< adjustment-index (len current-adjustments)) RESP-INVALID-ADJUSTMENT)
            
            (ok (map-set user-profiles
                user
                {
                    total-fees-paid: (get total-fees-paid user-profile),
                    total-rebates-received: (get total-rebates-received user-profile),
                    latest-transaction: (get latest-transaction user-profile),
                    user-segment: (get user-segment user-profile),
                    applied-adjustments: (unwrap-panic (as-max-len? 
                        (map update-adjustment-status 
                            (list adjustment-index)
                            (list u0)
                            current-adjustments
                            (list adjustment-index))
                        u20)),
                    activity-log: (get activity-log user-profile)
                }
            ))
        )
    )
)

;; Modified issue-rebate function to use native STX transfer
(define-public (issue-rebate (user principal) (rebate-amount uint) (rebate-currency (string-ascii 10)))
    (let (
        (user-profile (unwrap! (get-user-profile user) RESP-RATE-UNAVAILABLE))
        (converted-rebate-amount (unwrap! (convert-currency rebate-amount rebate-currency "STX") RESP-UNSUPPORTED-CURRENCY))
    )
        (begin
            (asserts! (is-eq tx-sender (var-get operator)) RESP-UNAUTHORIZED)
            (asserts! (<= converted-rebate-amount (get total-fees-paid user-profile)) RESP-REBATE-DENIED)
            ;; Use stx-transfer instead of contract-call
            (try! (stx-transfer? converted-rebate-amount (var-get operator) user))
            (ok (map-set user-profiles
                user
                {
                    total-fees-paid: (get total-fees-paid user-profile),
                    total-rebates-received: (+ (get total-rebates-received user-profile) converted-rebate-amount),
                    latest-transaction: (get latest-transaction user-profile),
                    user-segment: (get user-segment user-profile),
                    applied-adjustments: (get applied-adjustments user-profile),
                    activity-log: (unwrap-panic (as-max-len?
                        (append (get activity-log user-profile)
                            { 
                                transaction-value: (- u0 converted-rebate-amount),
                                timestamp: block-height,
                                transaction-currency: rebate-currency 
                            })
                        u50))
                }
            ))
        )
    )
)

;; Enhanced reporting functions
(define-read-only (generate-period-report (user principal) (period-id uint))
    (let (
        (user-profile (unwrap! (get-user-profile user) RESP-RATE-UNAVAILABLE))
    )
        (ok {
            total-paid: (get total-fees-paid user-profile),
            total-rebated: (get total-rebates-received user-profile),
            net-total: (- (get total-fees-paid user-profile) (get total-rebates-received user-profile)),
            applied-adjustments: (get applied-adjustments user-profile),
            transaction-history: (get activity-log user-profile)
        })
    )
)

(define-read-only (calculate-net-obligation (user principal))
    (let (
        (user-profile (unwrap! (get-user-profile user) RESP-RATE-UNAVAILABLE))
        (total-approved-adjustments (fold sum-approved-adjustments
            (get applied-adjustments user-profile)
            u0))
    )
        (ok (- (get total-fees-paid user-profile) total-approved-adjustments))
    )
)

;; Private helper for calculating total approved adjustments
(define-private (sum-approved-adjustments 
    (adjustment { adjustment-code: (string-ascii 10), adjustment-value: uint, adjustment-confirmed: bool }) 
    (running-total uint))
    (if (get adjustment-confirmed adjustment)
        (+ running-total (get adjustment-value adjustment))
        running-total)
)