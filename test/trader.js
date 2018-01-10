let Trader = artifacts.require('./Trader.sol');

contract('Trader', async (accounts) => {

  let trader, transactionData, callData, value = 10;

  it("should be able to retrieve total if owner", async () => {
    trader = await Trader.deployed();
    callData = await trader.getTotalBalance.call({from: accounts[0]});
    assert.equal(callData.toNumber(),0);
  });


  it("shouldn't be able to retrieve total if not owner", async () => {
    trader = await Trader.deployed();
    let error = false
    try{
      callData = await trader.getTotalBalance.call({from: accounts[3]});
    }catch(e){
      error = true;
    }
    assert.equal(error,true);
  });

  it("should be able to send funds to contract", async () => {
    trader = await Trader.deployed();

    transactionData = await trader.sendTransaction({from: accounts[3], value: value})
    callData = await trader.getBalance.call({from: accounts[3]});
    assert.equal(callData.toNumber(),value);
    
    transactionData = await trader.sendTransaction({from: accounts[4], value: value})
    callData = await trader.getBalance.call({from: accounts[4]});
    assert.equal(callData.toNumber(),value);

    callData = await trader.getTotalBalance.call({from: accounts[0]});
    assert.equal(callData.toNumber(),value*2);
  });

  it("should have increased the total balance", async () => {
    trader = await Trader.deployed();
    callData = await trader.getTotalBalance.call({from: accounts[0]});
    assert.equal(callData.toNumber(),value*2);
  });

  it("bot should be able to withdraw all available funds", async () => {
    trader = await Trader.deployed();
    transactionData = await trader.botWithdrawal({from: accounts[0]})
    callData = await trader.getTotalBalance.call({from: accounts[0]});
    assert.equal(callData.toNumber(),value*2);
    callData = await trader.getAvailableBalance.call({from: accounts[0]});
    assert.equal(callData.toNumber(),0);
  });

  it("bot should be able to deposit all funds back", async () => {
    trader = await Trader.deployed();
    transactionData = await trader.botDeposit({from: accounts[0], value: value*2})
    callData = await trader.getTotalBalance.call({from: accounts[0]});

    assert.equal(callData.toNumber(),value*4);
    callData = await trader.getAvailableBalance.call({from: accounts[0]});
    assert.equal(callData.toNumber(),value*4);
  });
  
});
