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