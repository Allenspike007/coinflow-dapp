
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

;; private functions
;;

;; public functions
;;
