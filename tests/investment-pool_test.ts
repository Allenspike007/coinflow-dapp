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

// Helper function to get account
function getAccount(accounts: Map<string, Account>, name: string): Account {
    const account = accounts.get(name);
    if (!account) throw new Error(`Account ${name} not found`);
    return account;
}

Clarinet.test({
    name: "Investment Pool - Contract initialization and basic setup",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = getAccount(accounts, 'deployer');
        
        // Test contract stats
        let block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'get-contract-stats', [], deployer.address)
        ]);
        
        const receipt = block.receipts[0];
        assert(isSuccess(receipt.result));
        
        // Verify initial state
        const statsResult = receipt.result;
        assert(statsResult.includes('total-pools: u0'));
        assert(statsResult.includes('total-proposals: u0'));
        assert(statsResult.includes('total-staked: u0'));
        assert(statsResult.includes('contract-paused: false'));
    },
});

Clarinet.test({
    name: "Investment Pool - Pool creation and validation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const creator = getAccount(accounts, 'wallet_1');
        
        // Test successful pool creation
        let block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'create-pool', [
                types.ascii('Conservative Growth Pool'),
                types.ascii('A low-risk investment pool focused on steady growth'),
                types.ascii('conservative'),
                types.uint(1000000), // 1 STX min stake
                types.uint(10000000000), // 10k STX max stake
                types.uint(100000000000), // 100k STX target
                types.uint(250) // 2.5% fee
            ], creator.address)
        ]);
        
        console.log('Pool creation result:', block.receipts[0].result);
        assert(isSuccess(block.receipts[0].result));
        
        const poolId = parseInt(block.receipts[0].result.replace('(ok u', '').replace(')', ''));
        assertEquals(poolId, 1);
        
        // Test get pool info
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'get-pool', [
                types.uint(poolId)
            ], creator.address)
        ]);
        
        console.log('Get pool result:', block.receipts[0].result);
        assert(block.receipts[0].result.includes('some'));
        assert(block.receipts[0].result.includes('Conservative Growth Pool'));
        
        // Test invalid pool parameters
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'create-pool', [
                types.ascii(''), // Empty name should fail
                types.ascii('Test description'),
                types.ascii('conservative'),
                types.uint(1000000),
                types.uint(10000000000),
                types.uint(100000000000),
                types.uint(250)
            ], creator.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u203')); // ERR-INVALID-PARAMETERS
        
        // Test invalid pool type
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'create-pool', [
                types.ascii('Test Pool'),
                types.ascii('Test description'),
                types.ascii('invalid-type'), // Invalid pool type
                types.uint(1000000),
                types.uint(10000000000),
                types.uint(100000000000),
                types.uint(250)
            ], creator.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u203')); // ERR-INVALID-PARAMETERS
    },
});

Clarinet.test({
    name: "Investment Pool - Staking functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const creator = getAccount(accounts, 'wallet_1');
        const staker = getAccount(accounts, 'wallet_2');
        
        // First create a pool
        let block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'create-pool', [
                types.ascii('Test Staking Pool'),
                types.ascii('Pool for testing staking functionality'),
                types.ascii('moderate'),
                types.uint(1000000), // 1 STX min stake
                types.uint(50000000000), // 50k STX max stake
                types.uint(1000000000000), // 1M STX target
                types.uint(300) // 3% fee
            ], creator.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        const poolId = parseInt(block.receipts[0].result.replace('(ok u', '').replace(')', ''));
        
        // Test successful staking
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'stake-in-pool', [
                types.uint(poolId),
                types.uint(5000000) // 5 STX
            ], staker.address)
        ]);
        
        console.log('Staking result:', block.receipts[0].result);
        assert(isSuccess(block.receipts[0].result));
        
        // Verify stake was recorded
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'get-stake', [
                types.uint(poolId),
                types.principal(staker.address)
            ], staker.address)
        ]);
        
        console.log('Get stake result:', block.receipts[0].result);
        assert(block.receipts[0].result.includes('some') || block.receipts[0].result.includes('amount'));
        assert(block.receipts[0].result.includes('amount: u5000000'));
        
        // Test staking below minimum
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'stake-in-pool', [
                types.uint(poolId),
                types.uint(500000) // 0.5 STX (below minimum)
            ], staker.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u207')); // ERR-MINIMUM-STAKE-NOT-MET
        
        // Test staking in non-existent pool
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'stake-in-pool', [
                types.uint(999), // Non-existent pool
                types.uint(5000000)
            ], staker.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u201')); // ERR-NOT-FOUND
    },
});

Clarinet.test({
    name: "Investment Pool - Governance proposals and voting",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const creator = getAccount(accounts, 'wallet_1');
        const staker1 = getAccount(accounts, 'wallet_2');
        const staker2 = getAccount(accounts, 'wallet_3');
        
        // Create pool and stake enough to have voting power
        let block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'create-pool', [
                types.ascii('Governance Test Pool'),
                types.ascii('Pool for testing governance functionality'),
                types.ascii('aggressive'),
                types.uint(1000000), // 1 STX min stake
                types.uint(100000000000), // 100k STX max stake
                types.uint(1000000000000), // 1M STX target
                types.uint(400) // 4% fee
            ], creator.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        const poolId = parseInt(block.receipts[0].result.replace('(ok u', '').replace(')', ''));
        
        // Stakers stake enough to have voting power
        chain.mineBlock([
            Tx.contractCall('investment-pool', 'stake-in-pool', [
                types.uint(poolId),
                types.uint(10000000) // 10 STX
            ], staker1.address),
            Tx.contractCall('investment-pool', 'stake-in-pool', [
                types.uint(poolId),
                types.uint(15000000) // 15 STX
            ], staker2.address)
        ]);
        
        // Test creating a proposal
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'create-proposal', [
                types.uint(poolId),
                types.ascii('investment'),
                types.ascii('Invest in DeFi Protocol'),
                types.ascii('Proposal to invest 50% of pool funds in a promising DeFi protocol for higher yields'),
                types.uint(50000000000), // 50k STX
                types.none()
            ], staker1.address)
        ]);
        
        console.log('Proposal creation result:', block.receipts[0].result);
        assert(isSuccess(block.receipts[0].result));
        const proposalId = parseInt(block.receipts[0].result.replace('(ok u', '').replace(')', ''));
        
        // Test voting on proposal
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'vote-on-proposal', [
                types.uint(proposalId),
                types.bool(true) // Vote for
            ], staker1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test second vote
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'vote-on-proposal', [
                types.uint(proposalId),
                types.bool(false) // Vote against
            ], staker2.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test duplicate voting (should fail)
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'vote-on-proposal', [
                types.uint(proposalId),
                types.bool(true)
            ], staker1.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u211')); // ERR-ALREADY-VOTED
        
        // Test voting with insufficient power
        const weakStaker = getAccount(accounts, 'wallet_4');
        
        // Try to create proposal without any stake (should fail)
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'create-proposal', [
                types.uint(poolId),
                types.ascii('investment'),
                types.ascii('Test Proposal'),
                types.ascii('Should fail due to no voting power'),
                types.uint(1000000),
                types.none()
            ], weakStaker.address)
        ]);
        
        console.log('Non-staker proposal result:', block.receipts[0].result);
        assert(isError(block.receipts[0].result)); // Should fail with insufficient voting power
    },
});

Clarinet.test({
    name: "Investment Pool - Multiple pools and user management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        const user2 = getAccount(accounts, 'wallet_2');
        
        // Create multiple pools
        const pools = [
            {
                name: 'Conservative Pool',
                type: 'conservative',
                minStake: 1000000,
                maxStake: 10000000000
            },
            {
                name: 'Aggressive Pool',
                type: 'aggressive',
                minStake: 5000000,
                maxStake: 50000000000
            }
        ];
        
        const poolIds: number[] = [];
        
        for (let i = 0; i < pools.length; i++) {
            const pool = pools[i];
            let block = chain.mineBlock([
                Tx.contractCall('investment-pool', 'create-pool', [
                    types.ascii(pool.name),
                    types.ascii(`Description for ${pool.name}`),
                    types.ascii(pool.type),
                    types.uint(pool.minStake),
                    types.uint(pool.maxStake),
                    types.uint(100000000000), // 100k STX target
                    types.uint(250) // 2.5% fee
                ], user1.address)
            ]);
            
            assert(isSuccess(block.receipts[0].result));
            poolIds.push(parseInt(block.receipts[0].result.replace('(ok u', '').replace(')', '')));
        }
        
        // Stake in multiple pools
        let block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'stake-in-pool', [
                types.uint(poolIds[0]),
                types.uint(2000000) // 2 STX
            ], user2.address),
            Tx.contractCall('investment-pool', 'stake-in-pool', [
                types.uint(poolIds[1]),
                types.uint(10000000) // 10 STX
            ], user2.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        assert(isSuccess(block.receipts[1].result));
        
        // Test user pools summary
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'get-user-pools', [
                types.principal(user2.address)
            ], user2.address)
        ]);
        
        console.log('Get user pools result:', block.receipts[0].result);
        assert(block.receipts[0].result.includes('some') || block.receipts[0].result.includes('pool-count'));
        assert(block.receipts[0].result.includes('pool-count: u2'));
        assert(block.receipts[0].result.includes('total-staked: u12000000'));
        
        // Test contract stats after activity
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'get-contract-stats', [], user1.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        assert(block.receipts[0].result.includes('total-pools: u2'));
        assert(block.receipts[0].result.includes('total-staked: u12000000'));
    },
});

Clarinet.test({
    name: "Investment Pool - Admin functions and security",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = getAccount(accounts, 'deployer');
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Test pause contract (deployer only)
        let block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'set-contract-paused', [
                types.bool(true)
            ], deployer.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test that regular users cannot pause contract
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'set-contract-paused', [
                types.bool(false)
            ], user1.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u200')); // ERR-UNAUTHORIZED
        
        // Test pool creation fails when paused
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'create-pool', [
                types.ascii('Paused Test Pool'),
                types.ascii('This should fail when contract is paused'),
                types.ascii('conservative'),
                types.uint(1000000),
                types.uint(10000000000),
                types.uint(100000000000),
                types.uint(250)
            ], user1.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u200')); // ERR-UNAUTHORIZED
        
        // Unpause contract
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'set-contract-paused', [
                types.bool(false)
            ], deployer.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test emergency withdrawal functions
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'enable-emergency-withdrawal', [], deployer.address)
        ]);
        
        assert(isSuccess(block.receipts[0].result));
        
        // Test unauthorized emergency withdrawal enable
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'enable-emergency-withdrawal', [], user1.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u200')); // ERR-UNAUTHORIZED
    },
});

Clarinet.test({
    name: "Investment Pool - Error handling and edge cases",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = getAccount(accounts, 'wallet_1');
        
        // Test operations on non-existent pool
        let block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'get-pool', [
                types.uint(999)
            ], user1.address)
        ]);
        
        assert(block.receipts[0].result === '(some none)' || block.receipts[0].result.includes('none'));
        
        // Test getting stake for non-existent pool
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'get-stake', [
                types.uint(999),
                types.principal(user1.address)
            ], user1.address)
        ]);
        
        assert(block.receipts[0].result === 'none' || block.receipts[0].result.includes('none'));
        
        // Test proposal operations on non-existent proposal
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'get-proposal', [
                types.uint(999)
            ], user1.address)
        ]);
        
        assert(block.receipts[0].result === 'none' || block.receipts[0].result.includes('none'));
        
        // Test voting on non-existent proposal
        block = chain.mineBlock([
            Tx.contractCall('investment-pool', 'vote-on-proposal', [
                types.uint(999),
                types.bool(true)
            ], user1.address)
        ]);
        
        assert(isError(block.receipts[0].result, 'u201')); // ERR-NOT-FOUND
    },
});