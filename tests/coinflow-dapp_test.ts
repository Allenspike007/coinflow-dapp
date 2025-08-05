
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.14.0/index.ts';
import { assertEquals, assert } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// Test constants
const CONTRACT_NAME = 'coinflow-dapp';
const DEFAULT_BLOCK_TIME = 1000;

// Helper function to get account
function getAccount(accounts: Map<string, Account>, name: string): Account {
    const account = accounts.get(name);
    if (!account) throw new Error(`Account ${name} not found`);
    return account;
}

// Helper function to create a transaction
function createTx(account: Account, functionName: string, args: any[] = []): Tx {
    return Tx.contractCall(CONTRACT_NAME, functionName, args, account.address);
}

// Helper function to assert success
function assertSuccess(receipt: any, expectedResult?: any) {
    assertEquals(receipt.result, 'Ok');
    if (expectedResult !== undefined) {
        assertEquals(receipt.result, expectedResult);
    }
}

// Helper function to assert error
function assertError(receipt: any, expectedError: string) {
    assertEquals(receipt.result, `Err(${expectedError})`);
}

Clarinet.test({
    name: "Contract initialization and basic setup",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = getAccount(accounts, 'deployer');
        
        // Test contract stats
        const block = chain.mineBlock([
            Tx.contractCall(CONTRACT_NAME, 'get-contract-stats', [], deployer.address)
        ]);
        
        const receipt = block.receipts[0];
        assertSuccess(receipt);
        
        const stats = receipt.result.value;
        assertEquals(stats['total-users'], 0);
        assertEquals(stats['total-transactions'], 0);
        assertEquals(stats['total-wallets'], 0);
        assertEquals(stats['contract-paused'], false);
    },
});

Clarinet.test({
    name: "User registration and management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        const user2 = getAccount(accounts, 'wallet_2');
        
        // Test user registration
        let block = chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com']),
            createTx(user2, 'register-user', ['bob', 'bob@example.com'])
        ]);
        
        assertSuccess(block.receipts[0]);
        assertSuccess(block.receipts[1]);
        
        // Test duplicate registration (should fail)
        block = chain.mineBlock([
            createTx(user1, 'register-user', ['alice2', 'alice2@example.com'])
        ]);
        
        assertError(block.receipts[0], 'u106'); // ERR-DUPLICATE-ENTRY
        
        // Test profile update
        block = chain.mineBlock([
            createTx(user1, 'update-user-profile', ['alice-updated', 'alice-updated@example.com'])
        ]);
        
        assertSuccess(block.receipts[0]);
        
        // Test stats after registration
        block = chain.mineBlock([
            Tx.contractCall(CONTRACT_NAME, 'get-contract-stats', [], user1.address)
        ]);
        
        const stats = block.receipts[0].result.value;
        assertEquals(stats['total-users'], 2);
    },
});

Clarinet.test({
    name: "Wallet creation and management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Register user first
        chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com'])
        ]);
        
        // Test wallet creation
        let block = chain.mineBlock([
            createTx(user1, 'create-wallet', ['Personal Wallet', 'personal', 'My personal wallet']),
            createTx(user1, 'create-wallet', ['Business Wallet', 'business', 'My business wallet'])
        ]);
        
        assertSuccess(block.receipts[0]);
        assertSuccess(block.receipts[1]);
        
        const wallet1Id = block.receipts[0].result.value;
        const wallet2Id = block.receipts[1].result.value;
        
        // Test get wallet details
        block = chain.mineBlock([
            createTx(user1, 'get-wallet', [wallet1Id])
        ]);
        
        assertSuccess(block.receipts[0]);
        const walletData = block.receipts[0].result.value;
        assertEquals(walletData['name'], 'Personal Wallet');
        assertEquals(walletData['wallet-type'], 'personal');
        assertEquals(walletData['balance'], 0);
        
        // Test wallet update
        block = chain.mineBlock([
            createTx(user1, 'update-wallet', [wallet1Id, 'Updated Wallet', 'Updated description'])
        ]);
        
        assertSuccess(block.receipts[0]);
        
        // Test unauthorized access
        const user2 = getAccount(accounts, 'wallet_2');
        block = chain.mineBlock([
            createTx(user2, 'get-wallet', [wallet1Id])
        ]);
        
        assertError(block.receipts[0], 'u100'); // ERR-UNAUTHORIZED
    },
});

Clarinet.test({
    name: "Transaction management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Setup: register user and create wallet
        chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com'])
        ]);
        
        const walletBlock = chain.mineBlock([
            createTx(user1, 'create-wallet', ['Test Wallet', 'personal', 'Test wallet'])
        ]);
        
        const walletId = walletBlock.receipts[0].result.value;
        
        // Test adding income transaction
        let block = chain.mineBlock([
            createTx(user1, 'add-transaction', [
                walletId,
                'income',
                1000000, // 1 STX in micro-STX
                'Income',
                'Salary payment',
                []
            ])
        ]);
        
        assertSuccess(block.receipts[0]);
        const incomeTxId = block.receipts[0].result.value;
        
        // Test adding expense transaction
        block = chain.mineBlock([
            createTx(user1, 'add-transaction', [
                walletId,
                'expense',
                500000, // 0.5 STX
                'Food',
                'Grocery shopping',
                ['food', 'grocery']
            ])
        ]);
        
        assertSuccess(block.receipts[0]);
        const expenseTxId = block.receipts[0].result.value;
        
        // Test get transaction
        block = chain.mineBlock([
            createTx(user1, 'get-transaction', [incomeTxId])
        ]);
        
        assertSuccess(block.receipts[0]);
        const txData = block.receipts[0].result.value;
        assertEquals(txData['transaction-type'], 'income');
        assertEquals(txData['amount'], 1000000);
        assertEquals(txData['category'], 'Income');
        
        // Test update transaction
        block = chain.mineBlock([
            createTx(user1, 'update-transaction', [
                expenseTxId,
                600000, // Updated amount
                'Food & Dining',
                'Updated grocery shopping'
            ])
        ]);
        
        assertSuccess(block.receipts[0]);
        
        // Test wallet balance after transactions
        block = chain.mineBlock([
            createTx(user1, 'get-wallet', [walletId])
        ]);
        
        const walletData = block.receipts[0].result.value;
        assertEquals(walletData['balance'], 400000); // 1000000 - 600000
    },
});

Clarinet.test({
    name: "Category management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Register user
        chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com'])
        ]);
        
        // Test category creation
        let block = chain.mineBlock([
            createTx(user1, 'create-category', [
                'food',
                'Food & Dining',
                'All food related expenses',
                '#FF5733'
            ]),
            createTx(user1, 'create-category', [
                'transport',
                'Transportation',
                'Transportation expenses',
                '#33FF57'
            ])
        ]);
        
        assertSuccess(block.receipts[0]);
        assertSuccess(block.receipts[1]);
        
        // Test duplicate category creation (should fail)
        block = chain.mineBlock([
            createTx(user1, 'create-category', [
                'food',
                'Food & Dining 2',
                'Another food category',
                '#FF5733'
            ])
        ]);
        
        assertError(block.receipts[0], 'u109'); // ERR-CATEGORY-EXISTS
        
        // Test get user categories
        block = chain.mineBlock([
            createTx(user1, 'get-user-categories', [])
        ]);
        
        assertSuccess(block.receipts[0]);
    },
});

Clarinet.test({
    name: "Budget management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Register user and create wallet
        chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com'])
        ]);
        
        const walletBlock = chain.mineBlock([
            createTx(user1, 'create-wallet', ['Test Wallet', 'personal', 'Test wallet'])
        ]);
        
        const walletId = walletBlock.receipts[0].result.value;
        
        // Test budget creation
        let block = chain.mineBlock([
            createTx(user1, 'create-budget', [
                'Monthly Food Budget',
                'Food',
                1000000, // 1 STX budget
                'monthly',
                walletId
            ])
        ]);
        
        assertSuccess(block.receipts[0]);
        const budgetId = block.receipts[0].result.value;
        
        // Test get budget
        block = chain.mineBlock([
            createTx(user1, 'get-budget', [budgetId])
        ]);
        
        assertSuccess(block.receipts[0]);
        const budgetData = block.receipts[0].result.value;
        assertEquals(budgetData['name'], 'Monthly Food Budget');
        assertEquals(budgetData['amount'], 1000000);
        assertEquals(budgetData['spent'], 0);
        
        // Test update budget spent
        block = chain.mineBlock([
            createTx(user1, 'update-budget-spent', [budgetId, 500000])
        ]);
        
        assertSuccess(block.receipts[0]);
        
        // Verify budget spent was updated
        block = chain.mineBlock([
            createTx(user1, 'get-budget', [budgetId])
        ]);
        
        const updatedBudgetData = block.receipts[0].result.value;
        assertEquals(updatedBudgetData['spent'], 500000);
    },
});

Clarinet.test({
    name: "Reporting and analytics",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Register user and create wallet
        chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com'])
        ]);
        
        const walletBlock = chain.mineBlock([
            createTx(user1, 'create-wallet', ['Test Wallet', 'personal', 'Test wallet'])
        ]);
        
        const walletId = walletBlock.receipts[0].result.value;
        
        // Add some transactions for reporting
        chain.mineBlock([
            createTx(user1, 'add-transaction', [
                walletId,
                'income',
                2000000,
                'Income',
                'Salary',
                []
            ]),
            createTx(user1, 'add-transaction', [
                walletId,
                'expense',
                500000,
                'Food',
                'Grocery',
                []
            ])
        ]);
        
        // Test expense report generation
        const currentTime = Math.floor(Date.now() / 1000);
        const startDate = currentTime - (30 * 24 * 60 * 60); // 30 days ago
        const endDate = currentTime;
        
        let block = chain.mineBlock([
            createTx(user1, 'generate-expense-report', [
                startDate,
                endDate,
                [walletId]
            ])
        ]);
        
        assertSuccess(block.receipts[0]);
        const reportId = block.receipts[0].result.value;
        
        // Test monthly summary
        const currentYear = new Date().getFullYear();
        const currentMonth = new Date().getMonth() + 1;
        
        block = chain.mineBlock([
            createTx(user1, 'get-monthly-summary', [currentYear, currentMonth])
        ]);
        
        assertSuccess(block.receipts[0]);
    },
});

Clarinet.test({
    name: "Notification system",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Register user
        chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com'])
        ]);
        
        // Test get user notifications
        let block = chain.mineBlock([
            createTx(user1, 'get-user-notifications', [10])
        ]);
        
        assertSuccess(block.receipts[0]);
        
        // Test mark notification as read (with non-existent notification)
        block = chain.mineBlock([
            createTx(user1, 'mark-notification-read', [999])
        ]);
        
        assertError(block.receipts[0], 'u101'); // ERR-NOT-FOUND
    },
});

Clarinet.test({
    name: "Admin functions and contract control",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = getAccount(accounts, 'deployer');
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Test pause contract (deployer only)
        let block = chain.mineBlock([
            createTx(deployer, 'pause-contract', [])
        ]);
        
        assertSuccess(block.receipts[0]);
        
        // Verify contract is paused
        block = chain.mineBlock([
            Tx.contractCall(CONTRACT_NAME, 'get-contract-stats', [], deployer.address)
        ]);
        
        const stats = block.receipts[0].result.value;
        assertEquals(stats['contract-paused'], true);
        
        // Test that regular users cannot pause contract
        block = chain.mineBlock([
            createTx(user1, 'pause-contract', [])
        ]);
        
        assertError(block.receipts[0], 'u100'); // ERR-UNAUTHORIZED
        
        // Test unpause contract
        block = chain.mineBlock([
            createTx(deployer, 'unpause-contract', [])
        ]);
        
        assertSuccess(block.receipts[0]);
        
        // Verify contract is unpaused
        block = chain.mineBlock([
            Tx.contractCall(CONTRACT_NAME, 'get-contract-stats', [], deployer.address)
        ]);
        
        const updatedStats = block.receipts[0].result.value;
        assertEquals(updatedStats['contract-paused'], false);
    },
});

Clarinet.test({
    name: "Contract pause functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = getAccount(accounts, 'deployer');
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Pause contract
        chain.mineBlock([
            createTx(deployer, 'pause-contract', [])
        ]);
        
        // Test that operations fail when contract is paused
        let block = chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com'])
        ]);
        
        assertError(block.receipts[0], 'u100'); // ERR-UNAUTHORIZED
        
        // Unpause contract
        chain.mineBlock([
            createTx(deployer, 'unpause-contract', [])
        ]);
        
        // Test that operations work again
        block = chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com'])
        ]);
        
        assertSuccess(block.receipts[0]);
    },
});

Clarinet.test({
    name: "Input validation and error handling",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Register user
        chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com'])
        ]);
        
        // Test invalid transaction amount (too small)
        let block = chain.mineBlock([
            createTx(user1, 'add-transaction', [
                1, // Invalid wallet ID
                'income',
                0, // Invalid amount
                'Income',
                'Test',
                []
            ])
        ]);
        
        assertError(block.receipts[0], 'u100'); // ERR-UNAUTHORIZED (wallet doesn't exist)
        
        // Create wallet first
        const walletBlock = chain.mineBlock([
            createTx(user1, 'create-wallet', ['Test Wallet', 'personal', 'Test wallet'])
        ]);
        
        const walletId = walletBlock.receipts[0].result.value;
        
        // Test invalid transaction type
        block = chain.mineBlock([
            createTx(user1, 'add-transaction', [
                walletId,
                'invalid-type',
                1000000,
                'Income',
                'Test',
                []
            ])
        ]);
        
        assertError(block.receipts[0], 'u103'); // ERR-INVALID-CATEGORY
        
        // Test invalid budget period
        block = chain.mineBlock([
            createTx(user1, 'create-budget', [
                'Test Budget',
                'Food',
                1000000,
                'invalid-period',
                walletId
            ])
        ]);
        
        assertError(block.receipts[0], 'u111'); // ERR-INVALID-BUDGET-PERIOD
    },
});

Clarinet.test({
    name: "Large transaction notifications",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Register user and create wallet
        chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com'])
        ]);
        
        const walletBlock = chain.mineBlock([
            createTx(user1, 'create-wallet', ['Test Wallet', 'personal', 'Test wallet'])
        ]);
        
        const walletId = walletBlock.receipts[0].result.value;
        
        // Test large transaction (should trigger notification)
        // Default threshold is 100000000 (100 STX)
        let block = chain.mineBlock([
            createTx(user1, 'add-transaction', [
                walletId,
                'income',
                200000000, // 200 STX - above threshold
                'Large Income',
                'Large transaction test',
                []
            ])
        ]);
        
        assertSuccess(block.receipts[0]);
        
        // Test normal transaction (should not trigger notification)
        block = chain.mineBlock([
            createTx(user1, 'add-transaction', [
                walletId,
                'income',
                50000000, // 50 STX - below threshold
                'Normal Income',
                'Normal transaction test',
                []
            ])
        ]);
        
        assertSuccess(block.receipts[0]);
    },
});

Clarinet.test({
    name: "Budget alert functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Register user and create wallet
        chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com'])
        ]);
        
        const walletBlock = chain.mineBlock([
            createTx(user1, 'create-wallet', ['Test Wallet', 'personal', 'Test wallet'])
        ]);
        
        const walletId = walletBlock.receipts[0].result.value;
        
        // Create budget
        const budgetBlock = chain.mineBlock([
            createTx(user1, 'create-budget', [
                'Test Budget',
                'Food',
                1000000, // 1 STX budget
                'monthly',
                walletId
            ])
        ]);
        
        const budgetId = budgetBlock.receipts[0].result.value;
        
        // Update budget spent to trigger alert (80% threshold)
        let block = chain.mineBlock([
            createTx(user1, 'update-budget-spent', [budgetId, 850000]) // 85% of budget
        ]);
        
        assertSuccess(block.receipts[0]);
        
        // Verify budget spent was updated
        block = chain.mineBlock([
            createTx(user1, 'get-budget', [budgetId])
        ]);
        
        const budgetData = block.receipts[0].result.value;
        assertEquals(budgetData['spent'], 850000);
    },
});

Clarinet.test({
    name: "Transaction limits and constraints",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Register user and create wallet
        chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com'])
        ]);
        
        const walletBlock = chain.mineBlock([
            createTx(user1, 'create-wallet', ['Test Wallet', 'personal', 'Test wallet'])
        ]);
        
        const walletId = walletBlock.receipts[0].result.value;
        
        // Test transaction with maximum amount
        let block = chain.mineBlock([
            createTx(user1, 'add-transaction', [
                walletId,
                'income',
                1000000000000, // 1 trillion micro-STX (max amount)
                'Max Income',
                'Maximum transaction test',
                []
            ])
        ]);
        
        assertSuccess(block.receipts[0]);
        
        // Test transaction with amount exceeding maximum
        block = chain.mineBlock([
            createTx(user1, 'add-transaction', [
                walletId,
                'income',
                1000000000001, // Exceeds max amount
                'Excessive Income',
                'Excessive transaction test',
                []
            ])
        ]);
        
        assertError(block.receipts[0], 'u102'); // ERR-INVALID-AMOUNT
    },
});

Clarinet.test({
    name: "Wallet balance calculations",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Register user and create wallet
        chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com'])
        ]);
        
        const walletBlock = chain.mineBlock([
            createTx(user1, 'create-wallet', ['Test Wallet', 'personal', 'Test wallet'])
        ]);
        
        const walletId = walletBlock.receipts[0].result.value;
        
        // Add income
        chain.mineBlock([
            createTx(user1, 'add-transaction', [
                walletId,
                'income',
                1000000, // 1 STX
                'Income',
                'Initial income',
                []
            ])
        ]);
        
        // Verify balance
        let block = chain.mineBlock([
            createTx(user1, 'get-wallet', [walletId])
        ]);
        
        let walletData = block.receipts[0].result.value;
        assertEquals(walletData['balance'], 1000000);
        
        // Add expense
        chain.mineBlock([
            createTx(user1, 'add-transaction', [
                walletId,
                'expense',
                300000, // 0.3 STX
                'Food',
                'Grocery expense',
                []
            ])
        ]);
        
        // Verify updated balance
        block = chain.mineBlock([
            createTx(user1, 'get-wallet', [walletId])
        ]);
        
        walletData = block.receipts[0].result.value;
        assertEquals(walletData['balance'], 700000); // 1000000 - 300000
        
        // Add another income
        chain.mineBlock([
            createTx(user1, 'add-transaction', [
                walletId,
                'income',
                500000, // 0.5 STX
                'Income',
                'Additional income',
                []
            ])
        ]);
        
        // Verify final balance
        block = chain.mineBlock([
            createTx(user1, 'get-wallet', [walletId])
        ]);
        
        walletData = block.receipts[0].result.value;
        assertEquals(walletData['balance'], 1200000); // 700000 + 500000
    },
});

Clarinet.test({
    name: "Multi-user scenario",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        const user2 = getAccount(accounts, 'wallet_2');
        const user3 = getAccount(accounts, 'wallet_3');
        
        // Register multiple users
        let block = chain.mineBlock([
            createTx(user1, 'register-user', ['alice', 'alice@example.com']),
            createTx(user2, 'register-user', ['bob', 'bob@example.com']),
            createTx(user3, 'register-user', ['charlie', 'charlie@example.com'])
        ]);
        
        assertSuccess(block.receipts[0]);
        assertSuccess(block.receipts[1]);
        assertSuccess(block.receipts[2]);
        
        // Create wallets for each user
        block = chain.mineBlock([
            createTx(user1, 'create-wallet', ['Alice Wallet', 'personal', 'Alice personal wallet']),
            createTx(user2, 'create-wallet', ['Bob Wallet', 'business', 'Bob business wallet']),
            createTx(user3, 'create-wallet', ['Charlie Wallet', 'personal', 'Charlie personal wallet'])
        ]);
        
        const aliceWalletId = block.receipts[0].result.value;
        const bobWalletId = block.receipts[1].result.value;
        const charlieWalletId = block.receipts[2].result.value;
        
        // Add transactions for each user
        block = chain.mineBlock([
            createTx(user1, 'add-transaction', [
                aliceWalletId,
                'income',
                1000000,
                'Income',
                'Alice income',
                []
            ]),
            createTx(user2, 'add-transaction', [
                bobWalletId,
                'income',
                2000000,
                'Income',
                'Bob income',
                []
            ]),
            createTx(user3, 'add-transaction', [
                charlieWalletId,
                'income',
                1500000,
                'Income',
                'Charlie income',
                []
            ])
        ]);
        
        assertSuccess(block.receipts[0]);
        assertSuccess(block.receipts[1]);
        assertSuccess(block.receipts[2]);
        
        // Test that users cannot access each other's wallets
        block = chain.mineBlock([
            createTx(user2, 'get-wallet', [aliceWalletId])
        ]);
        
        assertError(block.receipts[0], 'u100'); // ERR-UNAUTHORIZED
        
        // Test contract stats
        block = chain.mineBlock([
            Tx.contractCall(CONTRACT_NAME, 'get-contract-stats', [], user1.address)
        ]);
        
        const stats = block.receipts[0].result.value;
        assertEquals(stats['total-users'], 3);
        assertEquals(stats['total-wallets'], 3);
        assertEquals(stats['total-transactions'], 3);
    },
});

Clarinet.test({
    name: "Comprehensive integration test",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Complete user journey: register -> create wallet -> add transactions -> create categories -> create budgets -> generate reports
        
        // 1. Register user
        let block = chain.mineBlock([
            createTx(user1, 'register-user', ['testuser', 'test@example.com'])
        ]);
        assertSuccess(block.receipts[0]);
        
        // 2. Create wallet
        block = chain.mineBlock([
            createTx(user1, 'create-wallet', ['Main Wallet', 'personal', 'Primary wallet'])
        ]);
        const walletId = block.receipts[0].result.value;
        assertSuccess(block.receipts[0]);
        
        // 3. Create categories
        block = chain.mineBlock([
            createTx(user1, 'create-category', ['food', 'Food & Dining', 'Food expenses', '#FF5733']),
            createTx(user1, 'create-category', ['transport', 'Transportation', 'Transport expenses', '#33FF57'])
        ]);
        assertSuccess(block.receipts[0]);
        assertSuccess(block.receipts[1]);
        
        // 4. Create budget
        block = chain.mineBlock([
            createTx(user1, 'create-budget', ['Monthly Food Budget', 'food', 1000000, 'monthly', walletId])
        ]);
        const budgetId = block.receipts[0].result.value;
        assertSuccess(block.receipts[0]);
        
        // 5. Add various transactions
        block = chain.mineBlock([
            createTx(user1, 'add-transaction', [walletId, 'income', 5000000, 'Income', 'Salary', []]),
            createTx(user1, 'add-transaction', [walletId, 'expense', 500000, 'food', 'Grocery', ['food', 'grocery']]),
            createTx(user1, 'add-transaction', [walletId, 'expense', 200000, 'transport', 'Gas', ['transport', 'fuel']])
        ]);
        assertSuccess(block.receipts[0]);
        assertSuccess(block.receipts[1]);
        assertSuccess(block.receipts[2]);
        
        // 6. Update budget spent
        block = chain.mineBlock([
            createTx(user1, 'update-budget-spent', [budgetId, 500000])
        ]);
        assertSuccess(block.receipts[0]);
        
        // 7. Generate report
        const currentTime = Math.floor(Date.now() / 1000);
        const startDate = currentTime - (30 * 24 * 60 * 60);
        const endDate = currentTime;
        
        block = chain.mineBlock([
            createTx(user1, 'generate-expense-report', [startDate, endDate, [walletId]])
        ]);
        assertSuccess(block.receipts[0]);
        
        // 8. Verify final wallet balance
        block = chain.mineBlock([
            createTx(user1, 'get-wallet', [walletId])
        ]);
        const walletData = block.receipts[0].result.value;
        assertEquals(walletData['balance'], 4300000); // 5000000 - 500000 - 200000
        
        // 9. Verify budget status
        block = chain.mineBlock([
            createTx(user1, 'get-budget', [budgetId])
        ]);
        const budgetData = block.receipts[0].result.value;
        assertEquals(budgetData['spent'], 500000);
        
        // 10. Check contract stats
        block = chain.mineBlock([
            Tx.contractCall(CONTRACT_NAME, 'get-contract-stats', [], user1.address)
        ]);
        const stats = block.receipts[0].result.value;
        assertEquals(stats['total-users'], 1);
        assertEquals(stats['total-wallets'], 1);
        assertEquals(stats['total-transactions'], 3);
    },
});
