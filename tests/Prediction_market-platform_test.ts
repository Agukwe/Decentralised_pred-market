import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.14.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// Helper for getting error codes from receipts
function getErrCode(receipt: any): number {
  if (receipt.result.startsWith('(err ')) {
    const errValue = receipt.result.substring(5, receipt.result.length - 1);
    return parseInt(errValue.substring(1));
  }
  return -1;
}

Clarinet.test({
  name: "Ensure that contract can be initialized",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const oracle1 = accounts.get('wallet_1')!;
    const oracle2 = accounts.get('wallet_2')!;
    const oracle3 = accounts.get('wallet_3')!;
    
    // Initialize with 3 oracles
    let block = chain.mineBlock([
      Tx.contractCall(
        'prediction-market', 
        'initialize', 
        [
          types.list([
            types.principal(oracle1.address),
            types.principal(oracle2.address),
            types.principal(oracle3.address)
          ])
        ], 
        deployer.address
      )
    ]);
    
    // Check initialization succeeded
    assertEquals(block.receipts[0].result, '(ok true)');
    assertEquals(block.height, 2);
  },
});

Clarinet.test({
  name: "Only contract owner can initialize",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const nonOwner = accounts.get('wallet_1')!;
    const oracle1 = accounts.get('wallet_2')!;
    
    // Attempt to initialize from non-owner account
    let block = chain.mineBlock([
      Tx.contractCall(
        'prediction-market', 
        'initialize', 
        [types.list([types.principal(oracle1.address)])], 
        nonOwner.address
      )
    ]);
    
    // Check it fails with err-owner-only (u100)
    assertEquals(getErrCode(block.receipts[0]), 100);
  },
});

Clarinet.test({
  name: "Create a prediction market",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const oracle = accounts.get('wallet_1')!;
    const marketCreator = accounts.get('wallet_2')!;
    
    // First initialize the contract
    chain.mineBlock([
      Tx.contractCall(
        'prediction-market', 
        'initialize', 
        [types.list([types.principal(oracle.address)])], 
        deployer.address
      )
    ]);
      // Current block height for timing calculations
      const currentHeight = chain.blockHeight;
    
      // Create a new market
      let block = chain.mineBlock([
        Tx.contractCall(
          'prediction-market', 
          'create-market', 
          [
            types.utf8("Will BTC price exceed $100k by end of 2025?"), // description
            types.ascii("crypto"), // category
            types.list([types.utf8("Yes"), types.utf8("No")]), // outcomes
            types.uint(currentHeight + 1000), // resolution time
            types.uint(currentHeight + 900), // closing time
            types.uint(250), // fee percentage (2.5%)
            types.principal(oracle.address), // oracle
            types.uint(10000000), // oracle fee (10 STX)
            types.uint(1000000), // min trade amount (1 STX)
            types.some(types.utf8("Additional market info")) // additional data
          ], 
          marketCreator.address
        )
      ]);
      
      // Check market creation succeeds and returns market ID 1
      assertEquals(block.receipts[0].result, '(ok u1)');
    },
  });
  
  Clarinet.test({
    name: "Add liquidity to a market",
    async fn(chain: Chain, accounts: Map<string, Account>) {
      const deployer = accounts.get('deployer')!;
      const oracle = accounts.get('wallet_1')!;
      const marketCreator = accounts.get('wallet_2')!;
      const liquidityProvider = accounts.get('wallet_3')!;
      
      // Initialize and create market
      chain.mineBlock([
        Tx.contractCall(
          'prediction-market', 
          'initialize', 
          [types.list([types.principal(oracle.address)])], 
          deployer.address
        ),
        
        Tx.contractCall(
          'prediction-market', 
          'create-market', 
          [
            types.utf8("Will BTC price exceed $100k by end of 2025?"), // description
            types.ascii("crypto"), // category
            types.list([types.utf8("Yes"), types.utf8("No")]), // outcomes
            types.uint(chain.blockHeight + 1000), // resolution time
            types.uint(chain.blockHeight + 900), // closing time
            types.uint(250), // fee percentage (2.5%)
            types.principal(oracle.address), // oracle
            types.uint(10000000), // oracle fee (10 STX)
            types.uint(1000000), // min trade amount (1 STX)
            types.some(types.utf8("Additional market info")) // additional data
          ], 
          marketCreator.address
        )
      ]);
      
      // Add liquidity to the market
      let block = chain.mineBlock([
        Tx.contractCall(
          'prediction-market', 
          'add-liquidity', 
          [
            types.uint(1), // market ID
            types.uint(50000000) // amount (50 STX)
          ], 
          liquidityProvider.address
        )
      ]);
      
      // Check liquidity addition succeeded and returns correct share percentage
      const result = block.receipts[0].result;
      const expectedResult = '(ok (share-percentage u10000))'; // First LP gets 100% (10000 basis points)
      assertEquals(result, expectedResult);
    },
  });
  
  Clarinet.test({
    name: "Buy shares in a market outcome",
    async fn(chain: Chain, accounts: Map<string, Account>) {
      const deployer = accounts.get('deployer')!;
      const oracle = accounts.get('wallet_1')!;
      const marketCreator = accounts.get('wallet_2')!;
      const liquidityProvider = accounts.get('wallet_3')!;
      const trader = accounts.get('wallet_4')!;
      
      // Setup market with liquidity
      chain.mineBlock([
        // Initialize contract
        Tx.contractCall(
          'prediction-market', 
          'initialize', 
          [types.list([types.principal(oracle.address)])], 
          deployer.address
        ),
        
        // Create market
        Tx.contractCall(
          'prediction-market', 
          'create-market', 
          [
            types.utf8("Will BTC price exceed $100k by end of 2025?"), // description
            types.ascii("crypto"), // category
            types.list([types.utf8("Yes"), types.utf8("No")]), // outcomes
            types.uint(chain.blockHeight + 1000), // resolution time
            types.uint(chain.blockHeight + 900), // closing time
            types.uint(250), // fee percentage (2.5%)
            types.principal(oracle.address), // oracle
            types.uint(10000000), // oracle fee (10 STX)
            types.uint(1000000), // min trade amount (1 STX)
            types.some(types.utf8("Additional market info")) // additional data
          ], 
          marketCreator.address
        ),
        
        // Add liquidity
        Tx.contractCall(
          'prediction-market', 
          'add-liquidity', 
          [
            types.uint(1), // market ID
            types.uint(100000000) // amount (100 STX)
          ], 
          liquidityProvider.address
        )
      ]);
      
      // Buy shares in outcome 0 ("Yes")
      let block = chain.mineBlock([
        Tx.contractCall(
          'prediction-market', 
          'buy-shares', 
          [
            types.uint(1), // market ID
            types.uint(0), // outcome ID (Yes)
            types.uint(10000000) // amount (10 STX)
          ], 
          trader.address
        )
      ]);
      
      // Check share purchase succeeded
      // Note: The result depends on the exact calculation in the contract which we can't fully simulate here
      // So we just check it doesn't fail
      const receipt = block.receipts[0];
      assertEquals(receipt.result.startsWith('(ok'), true);
    },
  });
  
  Clarinet.test({
    name: "Oracle resolves market",
    async fn(chain: Chain, accounts: Map<string, Account>) {
      const deployer = accounts.get('deployer')!;
      const oracle = accounts.get('wallet_1')!;
      const marketCreator = accounts.get('wallet_2')!;
      const liquidityProvider = accounts.get('wallet_3')!;
      
      // Setup market with liquidity
      chain.mineBlock([
        // Initialize contract
        Tx.contractCall(
          'prediction-market', 
          'initialize', 
          [types.list([types.principal(oracle.address)])], 
          deployer.address
        ),
        
        // Create market with short timeframe
        Tx.contractCall(
          'prediction-market', 
          'create-market', 
          [
            types.utf8("Will BTC price exceed $100k by end of 2025?"), // description
            types.ascii("crypto"), // category
            types.list([types.utf8("Yes"), types.utf8("No")]), // outcomes
            types.uint(chain.blockHeight + 10), // resolution time
            types.uint(chain.blockHeight + 5), // closing time (soon)
            types.uint(250), // fee percentage (2.5%)
            types.principal(oracle.address), // oracle
            types.uint(10000000), // oracle fee (10 STX)
            types.uint(1000000), // min trade amount (1 STX)
            types.some(types.utf8("Additional market info")) // additional data
          ], 
          marketCreator.address
        ),
        
        // Add liquidity
        Tx.contractCall(
          'prediction-market', 
          'add-liquidity', 
          [
            types.uint(1), // market ID
            types.uint(100000000) // amount (100 STX)
          ], 
          liquidityProvider.address
        )
      ]);
      
      // Mine blocks to reach closing time
      for (let i = 0; i < 6; i++) {
        chain.mineBlock([]);
      }
      
      // Oracle resolves the market (outcome 1 = "No")
      let block = chain.mineBlock([
        Tx.contractCall(
          'prediction-market', 
          'resolve-market', 
          [
            types.uint(1), // market ID
            types.uint(1)  // outcome ID (No)
          ], 
          oracle.address
        )
      ]);
        // Check resolution succeeded
    assertEquals(block.receipts[0].result, '(ok true)');
},
});

Clarinet.test({
name: "Dispute market resolution",
async fn(chain: Chain, accounts: Map<string, Account>) {
  const deployer = accounts.get('deployer')!;
  const oracle = accounts.get('wallet_1')!;
  const marketCreator = accounts.get('wallet_2')!;
  const liquidityProvider = accounts.get('wallet_3')!;
  const disputer = accounts.get('wallet_4')!;
  
  // Setup and resolve market
  chain.mineBlock([
    // Initialize contract
    Tx.contractCall(
      'prediction-market', 
      'initialize', 
      [types.list([types.principal(oracle.address)])], 
      deployer.address
    ),
    
    // Create market with short timeframe
    Tx.contractCall(
      'prediction-market', 
      'create-market', 
      [
        types.utf8("Will BTC price exceed $100k by end of 2025?"), // description
        types.ascii("crypto"), // category
        types.list([types.utf8("Yes"), types.utf8("No")]), // outcomes
        types.uint(chain.blockHeight + 10), // resolution time
        types.uint(chain.blockHeight + 5), // closing time (soon)
        types.uint(250), // fee percentage (2.5%)
        types.principal(oracle.address), // oracle
        types.uint(10000000), // oracle fee (10 STX)
        types.uint(1000000), // min trade amount (1 STX)
        types.some(types.utf8("Additional market info")) // additional data
      ], 
      marketCreator.address
    ),
    
    // Add liquidity
    Tx.contractCall(
      'prediction-market', 
      'add-liquidity', 
      [
        types.uint(1), // market ID
        types.uint(100000000) // amount (100 STX)
      ], 
      liquidityProvider.address
    )
  ]);
  
  // Mine blocks to reach closing time
  for (let i = 0; i < 6; i++) {
    chain.mineBlock([]);
  }
  
  // Oracle resolves the market (outcome 1 = "No")
  chain.mineBlock([
    Tx.contractCall(
      'prediction-market', 
      'resolve-market', 
      [
        types.uint(1), // market ID
        types.uint(1)  // outcome ID (No)
      ], 
      oracle.address
    )
  ]);
  
  // User disputes the resolution (proposes outcome 0 = "Yes")
  let block = chain.mineBlock([
    Tx.contractCall(
      'prediction-market', 
      'dispute-resolution', 
      [
        types.uint(1), // market ID
        types.uint(0), // proposed outcome ID (Yes)
        types.uint(2000000) // stake amount (2 STX)
      ], 
      disputer.address
    )
  ]);
  
  // Check dispute succeeded
  assertEquals(block.receipts[0].result, '(ok true)');
},
});

Clarinet.test({
name: "Finalize market after dispute period",
async fn(chain: Chain, accounts: Map<string, Account>) {
  const deployer = accounts.get('deployer')!;
  const oracle = accounts.get('wallet_1')!;
  const marketCreator = accounts.get('wallet_2')!;
  const finalizer = accounts.get('wallet_3')!;
  
  // Setup and resolve market
  let setupBlock = chain.mineBlock([
    // Initialize contract
    Tx.contractCall(
      'prediction-market', 
      'initialize', 
      [types.list([types.principal(oracle.address)])], 
      deployer.address
    ),
    
    // Set shorter dispute period for testing
    Tx.contractCall(
      'prediction-market',
      'set-default-dispute-period-length',
      [types.uint(5)], // 5 blocks dispute period
      deployer.address
    ),
    
    // Create market with short timeframe
    Tx.contractCall(
      'prediction-market', 
      'create-market', 
      [
        types.utf8("Will BTC price exceed $100k by end of 2025?"), // description
        types.ascii("crypto"), // category
        types.list([types.utf8("Yes"), types.utf8("No")]), // outcomes
        types.uint(chain.blockHeight + 10), // resolution time
        types.uint(chain.blockHeight + 5), // closing time (soon)
        types.uint(250), // fee percentage (2.5%)
        types.principal(oracle.address), // oracle
        types.uint(10000000), // oracle fee (10 STX)
        types.uint(1000000), // min trade amount (1 STX)
        types.some(types.utf8("Additional market info")) // additional data
      ], 
      marketCreator.address
    )
  ]);
  
  // Mine blocks to reach closing time
  for (let i = 0; i < 6; i++) {
    chain.mineBlock([]);
  }
  
  // Oracle resolves the market
  chain.mineBlock([
    Tx.contractCall(
      'prediction-market', 
      'resolve-market', 
      [
        types.uint(1), // market ID
        types.uint(1)  // outcome ID (No)
      ], 
      oracle.address
    )
  ]);
  
  // Mine blocks to exceed dispute period
  for (let i = 0; i < 6; i++) {
    chain.mineBlock([]);
  }
  
  // Finalize the market
  let block = chain.mineBlock([
    Tx.contractCall(
      'prediction-market', 
      'finalize-market', 
      [types.uint(1)], // market ID
      finalizer.address
    )
  ]);
  
  // Check finalization succeeded
  assertEquals(block.receipts[0].result, '(ok true)');
},
});

Clarinet.test({
name: "Claim winnings after market resolution",
async fn(chain: Chain, accounts: Map<string, Account>) {
  const deployer = accounts.get('deployer')!;
  const oracle = accounts.get('wallet_1')!;
  const marketCreator = accounts.get('wallet_2')!;
  const liquidityProvider = accounts.get('wallet_3')!;
  const trader = accounts.get('wallet_4')!;
  const finalizer = accounts.get('wallet_5')!;
  
  // Setup market with liquidity
  chain.mineBlock([
    // Initialize contract
    Tx.contractCall(
      'prediction-market', 
      'initialize', 
      [types.list([types.principal(oracle.address)])], 
      deployer.address
    ),
    
    // Set shorter dispute period for testing
    Tx.contractCall(
      'prediction-market',
      'set-default-dispute-period-length',
      [types.uint(5)], // 5 blocks dispute period
      deployer.address
    ),
    
    // Create market
    Tx.contractCall(
      'prediction-market', 
      'create-market', 
      [
        types.utf8("Will BTC price exceed $100k by end of 2025?"), // description
        types.ascii("crypto"), // category
        types.list([types.utf8("Yes"), types.utf8("No")]), // outcomes
        types.uint(chain.blockHeight + 20), // resolution time
        types.uint(chain.blockHeight + 15), // closing time
        types.uint(250), // fee percentage (2.5%)
        types.principal(oracle.address), // oracle
        types.uint(10000000), // oracle fee (10 STX)
        types.uint(1000000), // min trade amount (1 STX)
        types.some(types.utf8("Additional market info")) // additional data
      ], 
      marketCreator.address
    ),
    
    // Add liquidity
    Tx.contractCall(
      'prediction-market', 
      'add-liquidity', 
      [
        types.uint(1), // market ID
        types.uint(100000000) // amount (100 STX)
      ], 
      liquidityProvider.address
    )
  ]);
  
  // Trader buys shares in outcome 1 ("No")
  chain.mineBlock([
    Tx.contractCall(
      'prediction-market', 
      'buy-shares', 
      [
        types.uint(1), // market ID
        types.uint(1), // outcome ID (No)
        types.uint(10000000) // amount (10 STX)
      ], 
      trader.address
    )
  ]);
  
  // Mine blocks to reach closing time
  for (let i = 0; i < 16; i++) {
    chain.mineBlock([]);
  }
  
  // Oracle resolves the market (outcome 1 = "No" - the trader's position)
  chain.mineBlock([
    Tx.contractCall(
      'prediction-market', 
      'resolve-market', 
      [
        types.uint(1), // market ID
        types.uint(1)  // outcome ID (No)
      ], 
      oracle.address
    )
  ]);
  
  // Mine blocks to exceed dispute period
  for (let i = 0; i < 6; i++) {
    chain.mineBlock([]);
  }