
;; coinflow-dapp
;; A comprehensive crypto expense tracking and bookkeeping wallet on the Stacks blockchain
;; Allows users to track expenses, categorize transactions, manage budgets, and generate financial reports

;; constants
;;

;; Contract Information
(define-constant CONTRACT-OWNER tx-sender)
(define-constant CONTRACT-VERSION "1.0.0")

;; Error Codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INVALID-CATEGORY (err u103))
(define-constant ERR-INVALID-DATE (err u104))
(define-constant ERR-BUDGET-EXCEEDED (err u105))
(define-constant ERR-DUPLICATE-ENTRY (err u106))
(define-constant ERR-INSUFFICIENT-BALANCE (err u107))
(define-constant ERR-INVALID-WALLET (err u108))
(define-constant ERR-CATEGORY-EXISTS (err u109))
(define-constant ERR-CATEGORY-NOT-FOUND (err u110))
(define-constant ERR-INVALID-BUDGET-PERIOD (err u111))
(define-constant ERR-BUDGET-NOT-FOUND (err u112))
(define-constant ERR-INVALID-PERCENTAGE (err u113))
(define-constant ERR-REPORT-GENERATION-FAILED (err u114))
(define-constant ERR-INVALID-TIMEFRAME (err u115))
(define-constant ERR-TRANSACTION-LIMIT-EXCEEDED (err u116))

;; Limits and Constraints
(define-constant MAX-TRANSACTIONS-PER-USER u10000)
(define-constant MAX-CATEGORIES-PER-USER u100)
(define-constant MAX-BUDGETS-PER-USER u50)
(define-constant MIN-TRANSACTION-AMOUNT u1)
(define-constant MAX-TRANSACTION-AMOUNT u1000000000000) ;; 1 trillion micro-STX
(define-constant MAX-CATEGORY-NAME-LENGTH u50)
(define-constant MAX-TRANSACTION-DESCRIPTION-LENGTH u200)
(define-constant MAX-WALLET-NAME-LENGTH u30)

;; Default Categories
(define-constant CATEGORY-FOOD "Food & Dining")
(define-constant CATEGORY-TRANSPORTATION "Transportation")
(define-constant CATEGORY-ENTERTAINMENT "Entertainment")
(define-constant CATEGORY-UTILITIES "Utilities")
(define-constant CATEGORY-SHOPPING "Shopping")
(define-constant CATEGORY-HEALTHCARE "Healthcare")
(define-constant CATEGORY-EDUCATION "Education")
(define-constant CATEGORY-INVESTMENT "Investment")
(define-constant CATEGORY-INCOME "Income")
(define-constant CATEGORY-OTHER "Other")

;; Transaction Types
(define-constant TX-TYPE-EXPENSE "expense")
(define-constant TX-TYPE-INCOME "income")
(define-constant TX-TYPE-TRANSFER "transfer")

;; Budget Periods
(define-constant BUDGET-PERIOD-DAILY "daily")
(define-constant BUDGET-PERIOD-WEEKLY "weekly")
(define-constant BUDGET-PERIOD-MONTHLY "monthly")
(define-constant BUDGET-PERIOD-YEARLY "yearly")

;; Status Constants
(define-constant STATUS-ACTIVE "active")
(define-constant STATUS-INACTIVE "inactive")
(define-constant STATUS-PENDING "pending")
(define-constant STATUS-COMPLETED "completed")

;; Wallet Types
(define-constant WALLET-TYPE-PERSONAL "personal")
(define-constant WALLET-TYPE-BUSINESS "business")
(define-constant WALLET-TYPE-SHARED "shared")

;; Currency/Token Constants
(define-constant STX-SYMBOL "STX")
(define-constant MICRO-STX-DECIMALS u6)

;; Time Constants (in seconds)
(define-constant SECONDS-PER-DAY u86400)
(define-constant SECONDS-PER-WEEK u604800)
(define-constant SECONDS-PER-MONTH u2592000) ;; 30 days
(define-constant SECONDS-PER-YEAR u31536000) ;; 365 days

;; Report Types
(define-constant REPORT-TYPE-EXPENSE-SUMMARY "expense-summary")
(define-constant REPORT-TYPE-INCOME-SUMMARY "income-summary")
(define-constant REPORT-TYPE-CATEGORY-BREAKDOWN "category-breakdown")
(define-constant REPORT-TYPE-BUDGET-ANALYSIS "budget-analysis")
(define-constant REPORT-TYPE-CASH-FLOW "cash-flow")

;; Permission Levels
(define-constant PERMISSION-OWNER u4)
(define-constant PERMISSION-ADMIN u3)
(define-constant PERMISSION-EDITOR u2)
(define-constant PERMISSION-VIEWER u1)
(define-constant PERMISSION-NONE u0)

;; Feature Flags
(define-constant FEATURE-MULTI-CURRENCY false)
(define-constant FEATURE-RECURRING-TRANSACTIONS true)
(define-constant FEATURE-BUDGET-ALERTS true)
(define-constant FEATURE-EXPORT-DATA true)
(define-constant FEATURE-SHARED-WALLETS false)

;; Notification Types
(define-constant NOTIFICATION-BUDGET-WARNING "budget-warning")
(define-constant NOTIFICATION-BUDGET-EXCEEDED "budget-exceeded")
(define-constant NOTIFICATION-LARGE-TRANSACTION "large-transaction")
(define-constant NOTIFICATION-MONTHLY-SUMMARY "monthly-summary")

;; Default Values
(define-constant DEFAULT-BUDGET-WARNING-THRESHOLD u80) ;; 80% of budget
(define-constant DEFAULT-LARGE-TRANSACTION-THRESHOLD u100000000) ;; 100 STX in micro-STX
(define-constant DEFAULT-CATEGORY CATEGORY-OTHER)
(define-constant DEFAULT-WALLET-TYPE WALLET-TYPE-PERSONAL)

;; data maps and vars
;;

;; Global Variables
(define-data-var contract-paused bool false)
(define-data-var total-users uint u0)
(define-data-var total-transactions uint u0)
(define-data-var total-wallets uint u0)

;; User Management
(define-map users
    { user-address: principal }
    {
        username: (string-ascii 30),
        email: (string-ascii 100),
        created-at: uint,
        last-active: uint,
        total-transactions: uint,
        total-wallets: uint,
        status: (string-ascii 20),
        preferences: {
            default-currency: (string-ascii 10),
            timezone: (string-ascii 50),
            notifications-enabled: bool,
            theme: (string-ascii 20)
        }
    }
)

;; Wallet Management
(define-map wallets
    { wallet-id: uint }
    {
        owner: principal,
        name: (string-ascii 30),
        wallet-type: (string-ascii 20),
        currency: (string-ascii 10),
        balance: uint,
        created-at: uint,
        updated-at: uint,
        status: (string-ascii 20),
        description: (string-ascii 200),
        is-default: bool
    }
)

;; Wallet Access Control (for shared wallets)
(define-map wallet-permissions
    { wallet-id: uint, user-address: principal }
    {
        permission-level: uint,
        granted-by: principal,
        granted-at: uint,
        can-view: bool,
        can-edit: bool,
        can-delete: bool,
        can-manage-users: bool
    }
)

;; Transaction Records
(define-map transactions
    { transaction-id: uint }
    {
        wallet-id: uint,
        user-address: principal,
        transaction-type: (string-ascii 20),
        amount: uint,
        category: (string-ascii 50),
        subcategory: (string-ascii 50),
        description: (string-ascii 200),
        date: uint,
        created-at: uint,
        updated-at: uint,
        status: (string-ascii 20),
        tags: (list 10 (string-ascii 30)),
        reference-id: (optional (string-ascii 100)),
        from-wallet: (optional uint),
        to-wallet: (optional uint),
        fee: uint,
        exchange-rate: (optional uint),
        location: (optional (string-ascii 100)),
        receipt-hash: (optional (string-ascii 64))
    }
)

;; Categories Management
(define-map categories
    { user-address: principal, category-name: (string-ascii 50) }
    {
        display-name: (string-ascii 50),
        description: (string-ascii 200),
        color: (string-ascii 7), ;; hex color code
        icon: (string-ascii 20),
        is-default: bool,
        is-active: bool,
        created-at: uint,
        transaction-count: uint,
        total-amount: uint,
        subcategories: (list 20 (string-ascii 50))
    }
)

;; Budget Management
(define-map budgets
    { budget-id: uint }
    {
        user-address: principal,
        wallet-id: (optional uint),
        name: (string-ascii 50),
        category: (string-ascii 50),
        amount: uint,
        spent: uint,
        period: (string-ascii 20),
        start-date: uint,
        end-date: uint,
        created-at: uint,
        updated-at: uint,
        status: (string-ascii 20),
        alert-threshold: uint,
        auto-renew: bool,
        notifications-sent: uint
    }
)

;; Recurring Transactions
(define-map recurring-transactions
    { recurring-id: uint }
    {
        user-address: principal,
        wallet-id: uint,
        template: {
            transaction-type: (string-ascii 20),
            amount: uint,
            category: (string-ascii 50),
            description: (string-ascii 200)
        },
        frequency: (string-ascii 20), ;; daily, weekly, monthly, yearly
        interval: uint, ;; every X periods
        next-execution: uint,
        last-execution: (optional uint),
        executions-count: uint,
        max-executions: (optional uint),
        end-date: (optional uint),
        is-active: bool,
        created-at: uint,
        updated-at: uint
    }
)

;; Reports and Analytics
(define-map reports
    { report-id: uint }
    {
        user-address: principal,
        report-type: (string-ascii 30),
        parameters: {
            start-date: uint,
            end-date: uint,
            wallet-ids: (list 10 uint),
            categories: (list 20 (string-ascii 50))
        },
        generated-at: uint,
        data-hash: (string-ascii 64),
        status: (string-ascii 20),
        file-url: (optional (string-ascii 200))
    }
)

;; Notifications
(define-map notifications
    { notification-id: uint }
    {
        user-address: principal,
        notification-type: (string-ascii 30),
        title: (string-ascii 100),
        message: (string-ascii 300),
        data: (optional (string-ascii 500)), ;; JSON string for additional data
        created-at: uint,
        read-at: (optional uint),
        is-read: bool,
        priority: uint, ;; 1=low, 2=medium, 3=high, 4=urgent
        expires-at: (optional uint)
    }
)

;; Tags System
(define-map transaction-tags
    { user-address: principal, tag-name: (string-ascii 30) }
    {
        display-name: (string-ascii 30),
        color: (string-ascii 7),
        usage-count: uint,
        created-at: uint,
        is-active: bool
    }
)

;; Exchange Rates (for multi-currency support when enabled)
(define-map exchange-rates
    { from-currency: (string-ascii 10), to-currency: (string-ascii 10) }
    {
        rate: uint, ;; rate * 1000000 for precision
        last-updated: uint,
        source: (string-ascii 50)
    }
)

;; Session Management
(define-map user-sessions
    { user-address: principal }
    {
        session-token: (string-ascii 64),
        created-at: uint,
        expires-at: uint,
        last-activity: uint,
        ip-address: (optional (string-ascii 45)),
        user-agent: (optional (string-ascii 200))
    }
)

;; ID Counters
(define-data-var next-wallet-id uint u1)
(define-data-var next-transaction-id uint u1)
(define-data-var next-budget-id uint u1)
(define-data-var next-recurring-id uint u1)
(define-data-var next-report-id uint u1)
(define-data-var next-notification-id uint u1)

;; User-specific counters
(define-map user-counters
    { user-address: principal }
    {
        transaction-count: uint,
        wallet-count: uint,
        category-count: uint,
        budget-count: uint,
        recurring-count: uint
    }
)

;; Lookup maps for efficient queries
(define-map user-wallets
    { user-address: principal }
    { wallet-ids: (list 50 uint) }
)

(define-map wallet-transactions
    { wallet-id: uint }
    { transaction-ids: (list 1000 uint) }
)

(define-map category-transactions
    { user-address: principal, category: (string-ascii 50) }
    { transaction-ids: (list 1000 uint) }
)

;; Monthly/Yearly aggregations for faster reporting
(define-map monthly-summaries
    { user-address: principal, year: uint, month: uint }
    {
        total-income: uint,
        total-expenses: uint,
        net-flow: int,
        transaction-count: uint,
        top-categories: (list 10 { category: (string-ascii 50), amount: uint }),
        updated-at: uint
    }
)

(define-map yearly-summaries
    { user-address: principal, year: uint }
    {
        total-income: uint,
        total-expenses: uint,
        net-flow: int,
        transaction-count: uint,
        monthly-breakdown: (list 12 uint),
        updated-at: uint
    }
)

;; private functions
;;

;; ========================================
;; VALIDATION FUNCTIONS
;; ========================================

;; Validate transaction amount
(define-private (is-valid-amount (amount uint))
    (and (>= amount MIN-TRANSACTION-AMOUNT)
         (<= amount MAX-TRANSACTION-AMOUNT)))

;; Validate string length
(define-private (is-valid-string-length (str (string-ascii 200)) (max-length uint))
    (<= (len str) max-length))

;; Validate transaction type
(define-private (is-valid-transaction-type (tx-type (string-ascii 20)))
    (or (is-eq tx-type TX-TYPE-EXPENSE)
        (is-eq tx-type TX-TYPE-INCOME)
        (is-eq tx-type TX-TYPE-TRANSFER)))

;; Validate budget period
(define-private (is-valid-budget-period (period (string-ascii 20)))
    (or (is-eq period BUDGET-PERIOD-DAILY)
        (is-eq period BUDGET-PERIOD-WEEKLY)
        (is-eq period BUDGET-PERIOD-MONTHLY)
        (is-eq period BUDGET-PERIOD-YEARLY)))

;; Validate wallet type
(define-private (is-valid-wallet-type (wallet-type (string-ascii 20)))
    (or (is-eq wallet-type WALLET-TYPE-PERSONAL)
        (is-eq wallet-type WALLET-TYPE-BUSINESS)
        (is-eq wallet-type WALLET-TYPE-SHARED)))

;; Validate permission level
(define-private (is-valid-permission-level (level uint))
    (and (>= level PERMISSION-NONE)
         (<= level PERMISSION-OWNER)))

;; Validate date (basic check for reasonable timestamp)
(define-private (is-valid-date (timestamp uint))
    (and (> timestamp u0)
         (< timestamp u4102444800))) ;; Year 2100

;; ========================================
;; AUTHORIZATION FUNCTIONS
;; ========================================

;; Check if user is contract owner
(define-private (is-contract-owner (user principal))
    (is-eq user CONTRACT-OWNER))

;; Check if user owns wallet
(define-private (is-wallet-owner (wallet-id uint) (user principal))
    (match (map-get? wallets {wallet-id: wallet-id})
        wallet-data (is-eq (get owner wallet-data) user)
        false))

;; Check wallet permission level
(define-private (get-wallet-permission (wallet-id uint) (user principal))
    (if (is-wallet-owner wallet-id user)
        PERMISSION-OWNER
        (match (map-get? wallet-permissions {wallet-id: wallet-id, user-address: user})
            permission-data (get permission-level permission-data)
            PERMISSION-NONE)))

;; Check if user can view wallet
(define-private (can-view-wallet (wallet-id uint) (user principal))
    (>= (get-wallet-permission wallet-id user) PERMISSION-VIEWER))

;; Check if user can edit wallet
(define-private (can-edit-wallet (wallet-id uint) (user principal))
    (>= (get-wallet-permission wallet-id user) PERMISSION-EDITOR))

;; Check if user can delete from wallet
(define-private (can-delete-wallet (wallet-id uint) (user principal))
    (>= (get-wallet-permission wallet-id user) PERMISSION-ADMIN))

;; ========================================
;; DATA RETRIEVAL FUNCTIONS
;; ========================================

;; Get next available ID for various entities
(define-private (get-next-wallet-id)
    (let ((current-id (var-get next-wallet-id)))
        (var-set next-wallet-id (+ current-id u1))
        current-id))

(define-private (get-next-transaction-id)
    (let ((current-id (var-get next-transaction-id)))
        (var-set next-transaction-id (+ current-id u1))
        current-id))

(define-private (get-next-budget-id)
    (let ((current-id (var-get next-budget-id)))
        (var-set next-budget-id (+ current-id u1))
        current-id))

(define-private (get-next-recurring-id)
    (let ((current-id (var-get next-recurring-id)))
        (var-set next-recurring-id (+ current-id u1))
        current-id))

(define-private (get-next-report-id)
    (let ((current-id (var-get next-report-id)))
        (var-set next-report-id (+ current-id u1))
        current-id))

(define-private (get-next-notification-id)
    (let ((current-id (var-get next-notification-id)))
        (var-set next-notification-id (+ current-id u1))
        current-id))

;; Get current timestamp
(define-private (get-current-time)
    block-height) ;; Using block height as timestamp proxy

;; ========================================
;; CALCULATION FUNCTIONS
;; ========================================

;; Calculate budget period end date
(define-private (calculate-budget-end-date (start-date uint) (period (string-ascii 20)))
    (if (is-eq period BUDGET-PERIOD-DAILY)
        (+ start-date SECONDS-PER-DAY)
        (if (is-eq period BUDGET-PERIOD-WEEKLY)
            (+ start-date SECONDS-PER-WEEK)
            (if (is-eq period BUDGET-PERIOD-MONTHLY)
                (+ start-date SECONDS-PER-MONTH)
                (+ start-date SECONDS-PER-YEAR)))))

;; Calculate next recurring transaction execution
(define-private (calculate-next-execution (last-execution uint) (frequency (string-ascii 20)) (interval uint))
    (let ((multiplier (if (is-eq frequency "daily") SECONDS-PER-DAY
                         (if (is-eq frequency "weekly") SECONDS-PER-WEEK
                             (if (is-eq frequency "monthly") SECONDS-PER-MONTH
                                 SECONDS-PER-YEAR)))))
        (+ last-execution (* multiplier interval))))

;; Calculate budget utilization percentage
(define-private (calculate-budget-utilization (spent uint) (budget-amount uint))
    (if (is-eq budget-amount u0)
        u0
        (/ (* spent u100) budget-amount)))

;; Extract year from timestamp
(define-private (get-year-from-timestamp (timestamp uint))
    ;; Simplified calculation - in real implementation would use proper date conversion
    (+ u2024 (/ timestamp SECONDS-PER-YEAR)))

;; Extract month from timestamp
(define-private (get-month-from-timestamp (timestamp uint))
    ;; Simplified calculation - in real implementation would use proper date conversion
    (+ u1 (mod (/ timestamp SECONDS-PER-MONTH) u12)))

;; ========================================
;; COUNTER MANAGEMENT FUNCTIONS
;; ========================================

;; Initialize user counters
(define-private (init-user-counters (user principal))
    (map-set user-counters
        {user-address: user}
        {
            transaction-count: u0,
            wallet-count: u0,
            category-count: u0,
            budget-count: u0,
            recurring-count: u0
        }))

;; Increment user transaction counter
(define-private (increment-user-transaction-count (user principal))
    (let ((current-counters (default-to 
                                {transaction-count: u0, wallet-count: u0, category-count: u0, budget-count: u0, recurring-count: u0}
                                (map-get? user-counters {user-address: user}))))
        (map-set user-counters
            {user-address: user}
            (merge current-counters {transaction-count: (+ (get transaction-count current-counters) u1)}))))

;; Increment user wallet counter
(define-private (increment-user-wallet-count (user principal))
    (let ((current-counters (default-to 
                                {transaction-count: u0, wallet-count: u0, category-count: u0, budget-count: u0, recurring-count: u0}
                                (map-get? user-counters {user-address: user}))))
        (map-set user-counters
            {user-address: user}
            (merge current-counters {wallet-count: (+ (get wallet-count current-counters) u1)}))))

;; Increment user budget counter
(define-private (increment-user-budget-count (user principal))
    (let ((current-counters (default-to 
                                {transaction-count: u0, wallet-count: u0, category-count: u0, budget-count: u0, recurring-count: u0}
                                (map-get? user-counters {user-address: user}))))
        (map-set user-counters
            {user-address: user}
            (merge current-counters {budget-count: (+ (get budget-count current-counters) u1)}))))

;; ========================================
;; LOOKUP TABLE MANAGEMENT
;; ========================================

;; Add wallet to user's wallet list
(define-private (add-wallet-to-user (user principal) (wallet-id uint))
    (let ((current-wallets (default-to 
                               {wallet-ids: (list)}
                               (map-get? user-wallets {user-address: user}))))
        (match (as-max-len? (append (get wallet-ids current-wallets) wallet-id) u50)
            updated-list (begin
                            (map-set user-wallets
                                {user-address: user}
                                {wallet-ids: updated-list})
                            true)
            false)))

;; Add transaction to wallet's transaction list
(define-private (add-transaction-to-wallet (wallet-id uint) (transaction-id uint))
    (let ((current-transactions (default-to 
                                    {transaction-ids: (list)}
                                    (map-get? wallet-transactions {wallet-id: wallet-id}))))
        (match (as-max-len? (append (get transaction-ids current-transactions) transaction-id) u1000)
            updated-list (begin
                            (map-set wallet-transactions
                                {wallet-id: wallet-id}
                                {transaction-ids: updated-list})
                            true)
            false)))

;; Add transaction to category's transaction list
(define-private (add-transaction-to-category (user principal) (category (string-ascii 50)) (transaction-id uint))
    (let ((current-transactions (default-to 
                                    {transaction-ids: (list)}
                                    (map-get? category-transactions {user-address: user, category: category}))))
        (match (as-max-len? (append (get transaction-ids current-transactions) transaction-id) u1000)
            updated-list (begin
                            (map-set category-transactions
                                {user-address: user, category: category}
                                {transaction-ids: updated-list})
                            true)
            false)))

;; ========================================
;; BUDGET CHECKING FUNCTIONS
;; ========================================

;; Check if adding amount would exceed budget
(define-private (would-exceed-budget (user principal) (category (string-ascii 50)) (amount uint))
    (let ((current-time (get-current-time))
          (year (get-year-from-timestamp current-time))
          (month (get-month-from-timestamp current-time)))
        ;; Get monthly summary for current month
        (match (map-get? monthly-summaries {user-address: user, year: year, month: month})
            summary-data
            ;; Check if adding this amount would exceed any budget for this category
            (let ((current-expenses (get total-expenses summary-data)))
                ;; This is a simplified check - in full implementation would check specific category budgets
                false) ;; Placeholder - would implement actual budget checking logic
            false)))

;; Check if budget alert threshold is reached
(define-private (should-send-budget-alert (budget-id uint))
    (match (map-get? budgets {budget-id: budget-id})
        budget-data
        (let ((utilization (calculate-budget-utilization (get spent budget-data) (get amount budget-data))))
            (>= utilization (get alert-threshold budget-data)))
        false))

;; ========================================
;; AGGREGATION UPDATE FUNCTIONS
;; ========================================

;; Update monthly summary with new transaction
(define-private (update-monthly-summary (user principal) (amount uint) (tx-type (string-ascii 20)) (category (string-ascii 50)))
    (let ((current-time (get-current-time))
          (year (get-year-from-timestamp current-time))
          (month (get-month-from-timestamp current-time)))
        (let ((current-summary (default-to 
                                   {total-income: u0, total-expenses: u0, net-flow: 0, transaction-count: u0, top-categories: (list), updated-at: u0}
                                   (map-get? monthly-summaries {user-address: user, year: year, month: month}))))
            (if (is-eq tx-type TX-TYPE-INCOME)
                ;; Update income
                (map-set monthly-summaries
                    {user-address: user, year: year, month: month}
                    (merge current-summary {
                        total-income: (+ (get total-income current-summary) amount),
                        net-flow: (+ (get net-flow current-summary) (to-int amount)),
                        transaction-count: (+ (get transaction-count current-summary) u1),
                        updated-at: current-time
                    }))
                ;; Update expenses
                (map-set monthly-summaries
                    {user-address: user, year: year, month: month}
                    (merge current-summary {
                        total-expenses: (+ (get total-expenses current-summary) amount),
                        net-flow: (- (get net-flow current-summary) (to-int amount)),
                        transaction-count: (+ (get transaction-count current-summary) u1),
                        updated-at: current-time
                    }))))))

;; ========================================
;; UTILITY FUNCTIONS
;; ========================================

;; Check if contract is paused
(define-private (is-contract-paused)
    (var-get contract-paused))

;; Generate notification ID and create notification
(define-private (create-notification (user principal) (notification-type (string-ascii 30)) (title (string-ascii 100)) (message (string-ascii 300)) (priority uint))
    (let ((notification-id (get-next-notification-id))
          (current-time (get-current-time)))
        (map-set notifications
            {notification-id: notification-id}
            {
                user-address: user,
                notification-type: notification-type,
                title: title,
                message: message,
                data: none,
                created-at: current-time,
                read-at: none,
                is-read: false,
                priority: priority,
                expires-at: none
            })
        (ok notification-id)))

;; Update category usage statistics
(define-private (update-category-stats (user principal) (category (string-ascii 50)) (amount uint))
    (match (map-get? categories {user-address: user, category-name: category})
        category-data
        (map-set categories
            {user-address: user, category-name: category}
            (merge category-data {
                transaction-count: (+ (get transaction-count category-data) u1),
                total-amount: (+ (get total-amount category-data) amount)
            }))
        ;; Category doesn't exist, could auto-create or ignore
        false))

;; Check if user has reached transaction limit
(define-private (has-reached-transaction-limit (user principal))
    (match (map-get? user-counters {user-address: user})
        counters (>= (get transaction-count counters) MAX-TRANSACTIONS-PER-USER)
        false))

;; Check if user has reached category limit
(define-private (has-reached-category-limit (user principal))
    (match (map-get? user-counters {user-address: user})
        counters (>= (get category-count counters) MAX-CATEGORIES-PER-USER)
        false))

;; Check if user has reached budget limit
(define-private (has-reached-budget-limit (user principal))
    (match (map-get? user-counters {user-address: user})
        counters (>= (get budget-count counters) MAX-BUDGETS-PER-USER)
        false))

;; public functions
;;
