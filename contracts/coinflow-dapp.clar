
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

;; public functions
;;
