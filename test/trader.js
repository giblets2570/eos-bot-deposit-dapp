let Trader = artifacts.require('./Trader.sol');

contract('Trader', async (accounts) => {

  let trader, transactionData, callData, value = 10, bot = 0, owner = 1, player1 = 2, player2 = 3

  it("should be able to retrieve total if owner", async () => {
    trader = await Trader.deployed();
    callData = await trader.getTotalBalance.call({from: accounts[bot]});
    assert.equal(callData.toNumber(),0);
  });


  it("shouldn't be able to retrieve total if not owner", async () => {
    trader = await Trader.deployed();
    let error = false
    try{
      callData = await trader.getTotalBalance.call({from: accounts[player1]});
    }catch(e){
      error = true;
    }
    assert.equal(error,true);
  });

  it("should be able to send funds to contract", async () => {
    trader = await Trader.deployed();

    transactionData = await trader.sendTransaction({from: accounts[player1], value: value})
    callData = await trader.getBalance.call({from: accounts[player1]});
    assert.equal(callData.toNumber(),value);
    
    transactionData = await trader.sendTransaction({from: accounts[player2], value: value})
    callData = await trader.getBalance.call({from: accounts[player2]});
    assert.equal(callData.toNumber(),value);

    callData = await trader.getTotalBalance.call({from: accounts[bot]});
    assert.equal(callData.toNumber(),value*2);
  });

  it("should have increased the total balance", async () => {
    trader = await Trader.deployed();
    callData = await trader.getTotalBalance.call({from: accounts[bot]});
    assert.equal(callData.toNumber(),value*2);
  });

  it("bot should be able to withdraw all available funds", async () => {
    trader = await Trader.deployed();
    transactionData = await trader.botWithdrawal({from: accounts[bot]})
    callData = await trader.getTotalBalance.call({from: accounts[bot]});
    assert.equal(callData.toNumber(),value*2);
    callData = await trader.getAvailableBalance.call({from: accounts[bot]});
    assert.equal(callData.toNumber(),0);
  });

  it("bot should be able to deposit all funds back and winnings destributed correctly", async () => {
    trader = await Trader.deployed();

    let amountToDeposit = Math.floor(value*4)

    transactionData = await trader.botDeposit({from: accounts[bot], value: amountToDeposit})

    callData = await trader.getTotalBalance.call({from: accounts[bot]});
    assert.equal(callData.toNumber(),amountToDeposit);
    
    callData = await trader.getAvailableBalance.call({from: accounts[bot]});
    assert.equal(callData.toNumber(),amountToDeposit);

    let promises = [
      trader.getBalance.call({from: accounts[player1]}),
      trader.getBalance.call({from: accounts[player2]}),
      trader.getBalance.call({from: accounts[bot]}),
      trader.getBalance.call({from: accounts[owner]})
    ]

    let amounts = await Promise.all(promises)
    
    assert.equal(amounts[0].toNumber(),Math.floor(value*1.6));
    assert.equal(amounts[1].toNumber(),Math.floor(value*1.6));
    assert.equal(amounts[2].toNumber(),Math.floor(value*0.4));
    assert.equal(amounts[3].toNumber(),Math.floor(value*0.4));

    let total = amounts.reduce((c,amount) => c + amount.toNumber(), 0);

    assert.equal(total, amountToDeposit);

  });

  it("player should be able to withdraw their funds", async () => {
    trader = await Trader.deployed();
    let amountToWithdraw = Math.floor(value);
    transactionData = await trader.playerWithdrawal(amountToWithdraw,{from: accounts[player1]});

    callData = await trader.getTotalBalance.call({from: accounts[bot]});
    assert.equal(callData.toNumber(),Math.floor(value*4) - amountToWithdraw);
      
    callData = await trader.getAvailableBalance.call({from: accounts[bot]});
    assert.equal(callData.toNumber(),Math.floor(value*4) - amountToWithdraw);

    callData = await trader.getBalance.call({from: accounts[player1]});
    assert.equal(callData.toNumber(),Math.floor(value*1.6) - amountToWithdraw);
  });

  it("player shouldn't be able to deposit if amount becomes greater than maxBalance", async () => {
    trader = await Trader.deployed();
    let amountToDeposit = value * 100000;
    let error = false;
    try{
      transactionData = await trader.sendTransaction({from: accounts[player1], value: amountToDeposit});
    }catch(e){
      error = true;
    }
    assert.equal(error, true);
  });
  
});
