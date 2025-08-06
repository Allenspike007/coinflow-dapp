
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.14.0/index.ts';
import { assertEquals, assert } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// Helper function to check if result is success
function isSuccess(result: string): boolean {
    return result.startsWith('(ok');
}

// Helper function to check if result is error
function isError(result: string, errorCode?: string): boolean {
    if (errorCode) {
        return result === `(err ${errorCode})`;
    }
    return result.startsWith('(err ');
}

Clarinet.test({
    name: "Basic contract functionality test",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = getAccount(accounts, 'deployer');
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Test contract stats
        let block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'get-contract-stats', [], deployer.address)
        ]);
        
        const receipt = block.receipts[0];
        assert(isSuccess(receipt.result));
        
        // Test user registration
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'register-user', [
                types.ascii('alice'),
                types.ascii('alice@example.com')
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test wallet creation
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'create-wallet', [
                types.ascii('Test Wallet'),
                types.ascii('personal'),
                types.ascii('Test wallet description')
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test category creation
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'create-category', [
                types.ascii('food'),
                types.ascii('Food & Dining'),
                types.ascii('Food expenses'),
                types.ascii('#FF5733')
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test admin functions
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'pause-contract', [], deployer.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'unpause-contract', [], deployer.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
    },
});

Clarinet.test({
    name: "User management test",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        const user2 = getAccount(accounts, 'wallet_2');
        
        // Register first user
        let block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'register-user', [
                types.ascii('alice'),
                types.ascii('alice@example.com')
            ], user1.address)
        ]);
        
        console.log('First user registration result:', block.receipts[0].result);
        assert(isSuccess(block.receipts[0].result));
        
        // Register second user
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'register-user', [
                types.ascii('bob'),
                types.ascii('bob@example.com')
            ], user2.address)
        ]);
        
        console.log('Second user registration result:', block.receipts[0].result);
        assert(isSuccess(block.receipts[0].result));
        
        // Test duplicate registration (should fail)
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'register-user', [
                types.ascii('alice2'),
                types.ascii('alice2@example.com')
            ], user1.address)
        ]);
        
        console.log('Duplicate registration result:', block.receipts[0].result);
        assert(isError(block.receipts[0].result, 'u106')); // ERR-DUPLICATE-ENTRY
        
        // Test profile update
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'update-user-profile', [
                types.ascii('alice-updated'),
                types.ascii('alice-updated@example.com')
            ], user1.address)
        ]);
        
        console.log('Profile update result:', block.receipts[0].result);
        assert(isSuccess(block.receipts[0].result));
    },
});

Clarinet.test({
    name: "Wallet management test",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Register user first
        chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'register-user', [
                types.ascii('alice'),
                types.ascii('alice@example.com')
            ], user1.address)
        ]);
        
        // Create wallet
        let block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'create-wallet', [
                types.ascii('Personal Wallet'),
                types.ascii('personal'),
                types.ascii('My personal wallet')
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Get wallet ID from result
        const walletId = parseInt(block.receipts[0].result.replace('(ok u', '').replace(')', ''));
        
        // Test get wallet
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'get-wallet', [
                types.uint(walletId)
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test wallet update
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'update-wallet', [
                types.uint(walletId),
                types.ascii('Updated Wallet'),
                types.ascii('Updated description')
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test unauthorized access
        const user2 = getAccount(accounts, 'wallet_2');
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'get-wallet', [
                types.uint(walletId)
            ], user2.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u100')); // ERR-UNAUTHORIZED
    },
});

Clarinet.test({
    name: "Transaction management test",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Setup: register user and create wallet
        chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'register-user', [
                types.ascii('alice'),
                types.ascii('alice@example.com')
            ], user1.address)
        ]);
        
        const walletBlock = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'create-wallet', [
                types.ascii('Test Wallet'),
                types.ascii('personal'),
                types.ascii('Test wallet')
            ], user1.address)
        ]);
        
        const walletId = parseInt(walletBlock.receipts[0].result.replace('(ok u', '').replace(')', ''));
        
        // Test adding income transaction
        let block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'add-transaction', [
                types.uint(walletId),
                types.ascii('income'),
                types.uint(1000000), // 1 STX in micro-STX
                types.ascii('Income'),
                types.ascii('Salary payment'),
                types.list([])
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        const incomeTxId = parseInt(block.receipts[0].result.replace('(ok u', '').replace(')', ''));
        
        // Test adding expense transaction
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'add-transaction', [
                types.uint(walletId),
                types.ascii('expense'),
                types.uint(500000), // 0.5 STX
                types.ascii('Food'),
                types.ascii('Grocery shopping'),
                types.list([types.ascii('food'), types.ascii('grocery')])
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        const expenseTxId = parseInt(block.receipts[0].result.replace('(ok u', '').replace(')', ''));
        
        // Test get transaction
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'get-transaction', [
                types.uint(incomeTxId)
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test update transaction
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'update-transaction', [
                types.uint(expenseTxId),
                types.uint(600000), // Updated amount
                types.ascii('Food & Dining'),
                types.ascii('Updated grocery shopping')
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
    },
});

Clarinet.test({
    name: "Category management test",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Register user
        chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'register-user', [
                types.ascii('alice'),
                types.ascii('alice@example.com')
            ], user1.address)
        ]);
        
        // Test category creation
        let block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'create-category', [
                types.ascii('food'),
                types.ascii('Food & Dining'),
                types.ascii('All food related expenses'),
                types.ascii('#FF5733')
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test duplicate category creation (should fail)
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'create-category', [
                types.ascii('food'),
                types.ascii('Food & Dining 2'),
                types.ascii('Another food category'),
                types.ascii('#FF5733')
            ], user1.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u109')); // ERR-CATEGORY-EXISTS
        
        // Test get user categories
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'get-user-categories', [], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
    },
});

Clarinet.test({
    name: "Budget management test",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Register user and create wallet
        chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'register-user', [
                types.ascii('alice'),
                types.ascii('alice@example.com')
            ], user1.address)
        ]);
        
        const walletBlock = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'create-wallet', [
                types.ascii('Test Wallet'),
                types.ascii('personal'),
                types.ascii('Test wallet')
            ], user1.address)
        ]);
        
        const walletId = parseInt(walletBlock.receipts[0].result.replace('(ok u', '').replace(')', ''));
        
        // Test budget creation
        let block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'create-budget', [
                types.ascii('Monthly Food Budget'),
                types.ascii('Food'),
                types.uint(1000000), // 1 STX budget
                types.ascii('monthly'),
                types.some(types.uint(walletId))
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        const budgetId = parseInt(block.receipts[0].result.replace('(ok u', '').replace(')', ''));
        
        // Test get budget
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'get-budget', [
                types.uint(budgetId)
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test update budget spent
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'update-budget-spent', [
                types.uint(budgetId),
                types.uint(500000)
            ], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
    },
});

Clarinet.test({
    name: "Admin functions test",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = getAccount(accounts, 'deployer');
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Test pause contract (deployer only)
        let block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'pause-contract', [], deployer.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test that regular users cannot pause contract
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'pause-contract', [], user1.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u100')); // ERR-UNAUTHORIZED
        
        // Test unpause contract
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'unpause-contract', [], deployer.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
    },
});

Clarinet.test({
    name: "Error handling test",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Test invalid transaction (wallet doesn't exist)
        let block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'add-transaction', [
                types.uint(999), // Non-existent wallet
                types.ascii('income'),
                types.uint(1000000),
                types.ascii('Income'),
                types.ascii('Test'),
                types.list([])
            ], user1.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u100')); // ERR-UNAUTHORIZED
        
        // Test invalid budget period
        chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'register-user', [
                types.ascii('alice'),
                types.ascii('alice@example.com')
            ], user1.address)
        ]);
        
        const walletBlock = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'create-wallet', [
                types.ascii('Test Wallet'),
                types.ascii('personal'),
                types.ascii('Test wallet')
            ], user1.address)
        ]);
        
        const walletId = parseInt(walletBlock.receipts[0].result.replace('(ok u', '').replace(')', ''));
        
        block = chain.mineBlock([
            Tx.contractCall('coinflow-dapp', 'create-budget', [
                types.ascii('Test Budget'),
                types.ascii('Food'),
                types.uint(1000000),
                types.ascii('invalid-period'),
                types.some(types.uint(walletId))
            ], user1.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u111')); // ERR-INVALID-BUDGET-PERIOD
    },
});

// Helper function to get account
function getAccount(accounts: Map<string, Account>, name: string): Account {
    const account = accounts.get(name);
    if (!account) throw new Error(`Account ${name} not found`);
    return account;
}
