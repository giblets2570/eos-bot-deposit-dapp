let Trader = artifacts.require('./Trader.sol');

contract('Trader', async (accounts) => {

  let trader, transactionData, callData, value = 10, bot = 0, owner = 1, player1 = 2, player2 = 3

  beforeEach(async () => {
    let owners = [accounts[bot],accounts[owner]];
    trader = await Trader.new(owners, accounts[bot], 60, 100);
  })


  describe('before any funds are added', async () => {

    it("should be able to send funds to contract", async () => {

      await trader.addPlayer(accounts[player1],{from: accounts[bot]});
      await trader.addPlayer(accounts[player2],{from: accounts[bot]});

      await trader.sendTransaction({from: accounts[player1], value: value})
      callData = await trader.getBalance.call({from: accounts[player1]});
      assert.equal(callData.toNumber(),value);
      
      await trader.sendTransaction({from: accounts[player2], value: value})
      callData = await trader.getBalance.call({from: accounts[player2]});
      assert.equal(callData.toNumber(),value);

      assert.equal(web3.eth.getBalance(trader.address).toNumber(),value*2);
    });

    it("player shouldn't be able to deposit if amount becomes greater than maxBalance", async () => {
      let amountToDeposit = value * 100000;
      let error = false;
      try{
        await trader.sendTransaction({from: accounts[player1], value: amountToDeposit});
      }catch(e){
        error = true;
      }
      assert.equal(error, true);
    });

    it("owner should be able to change the maxBalance", async () => {
      let newMaxBalance = Math.pow(10,9);
      
      await trader.setMaxBalance(newMaxBalance,{from: accounts[owner]});

      callData = await trader.getMaxBalance.call({from: accounts[bot]});
      assert.equal(callData.toNumber(),newMaxBalance);
    });

    it("non owner shouldn't be able to change the maxBalance", async () => {
      let newMaxBalance = Math.pow(10,10);

      callData = await trader.getMaxBalance.call({from: accounts[bot]});
      let oldMaxBalance = callData.toNumber();

      let error = false;
      try{
        await trader.setMaxBalance(newMaxBalance,{from: accounts[player1]});
      }catch(e){
        error = true;
      }
      assert.equal(error,true);

      callData = await trader.getMaxBalance.call({from: accounts[bot]});
      assert(callData.toNumber(), oldMaxBalance);
    });
  });

  describe('after funds are added', async () => {
    let amountDeposited;
    beforeEach(async () => {

      await trader.addPlayer(accounts[player1],{from: accounts[bot]});
      await trader.addPlayer(accounts[player2],{from: accounts[bot]});

      amountDeposited = 0;

      await trader.sendTransaction({from: accounts[player1], value: value})
      amountDeposited += value;
      callData = await trader.getBalance.call({from: accounts[player1]});
      assert.equal(callData.toNumber(),value);

      await trader.sendTransaction({from: accounts[player2], value: value})
      callData = await trader.getBalance.call({from: accounts[player2]});
      amountDeposited += value;
      assert.equal(callData.toNumber(),value);
    });
    

    it("bot should be able to withdraw all funds", async () => {

      await trader.botWithdrawal({from: accounts[bot]})
      assert.equal(web3.eth.getBalance(trader.address).toNumber(),0);

    });

    it("player should be able to withdraw their funds", async () => {
      let amountToWithdraw = Math.floor(value);
      await trader.userWithdrawal(amountToWithdraw,{from: accounts[player1]});

      assert.equal(web3.eth.getBalance(trader.address).toNumber(),Math.floor(amountDeposited) - amountToWithdraw);

      callData = await trader.getBalance.call({from: accounts[player1]});
      assert.equal(callData.toNumber(),value - amountToWithdraw);
    });
  })

  describe('when the bot is on a trade', async () => {

    let amountDeposited;
    beforeEach(async () => {

      await trader.addPlayer(accounts[player1],{from: accounts[bot]});
      await trader.addPlayer(accounts[player2],{from: accounts[bot]});

      amountDeposited = 0;

      let promises = [bot,owner,player1,player2].map(async (user) => {
        await trader.sendTransaction({from: accounts[user], value: value})
        amountDeposited += value;
        callData = await trader.getBalance.call({from: accounts[user]});
        assert.equal(callData.toNumber(),value);
      })

      await Promise.all(promises);

      await trader.botWithdrawal({from: accounts[bot]})
    });

    it("bot should be able to deposit all funds back and losses distributed evenly", async () => {

      let amountToDeposit = Math.floor(value)

      await trader.botDeposit({from: accounts[bot], value: amountToDeposit})

      assert.equal(web3.eth.getBalance(trader.address).toNumber(),amountToDeposit);

      let promises = [
        trader.getBalance.call({from: accounts[player1]}),
        trader.getBalance.call({from: accounts[player2]}),
        trader.getBalance.call({from: accounts[bot]}),
        trader.getBalance.call({from: accounts[owner]})
      ]

      let amounts = await Promise.all(promises)
      
      assert.equal(amounts[0].toNumber(),Math.floor(value*0.2));
      assert.equal(amounts[1].toNumber(),Math.floor(value*0.2));
      assert.equal(amounts[2].toNumber(),Math.floor(value*0.3));
      assert.equal(amounts[3].toNumber(),Math.floor(value*0.3));

      let total = amounts.reduce((c,amount) => c + amount.toNumber(), 0);

      assert.equal(total, amountToDeposit);

    });

    it("bot should be able to deposit all funds back and winnings destributed correctly", async () => {

      let amountToDeposit = Math.floor(value*8)

      await trader.botDeposit({from: accounts[bot], value: amountToDeposit})

      assert.equal(web3.eth.getBalance(trader.address).toNumber(),amountToDeposit);

      let promises = [
        trader.getBalance.call({from: accounts[player1]}),
        trader.getBalance.call({from: accounts[player2]}),
        trader.getBalance.call({from: accounts[bot]}),
        trader.getBalance.call({from: accounts[owner]})
      ]

      let amounts = await Promise.all(promises)
      
      assert.equal(amounts[0].toNumber(),Math.floor(value*1.6));
      assert.equal(amounts[1].toNumber(),Math.floor(value*1.6));
      assert.equal(amounts[2].toNumber(),Math.floor(value*2.4));
      assert.equal(amounts[3].toNumber(),Math.floor(value*2.4));

      let total = amounts.reduce((c,amount) => c + amount.toNumber(), 0);

      assert.equal(total, amountToDeposit);

    });

    it("shouldn't be able to make deposits when onTrade", async () => {
      let error = false;
      try{
        await trader.sendTransaction({from: accounts[player1], value: value})
      }catch(e){
        error = true;
      }
      assert.equal(error, true);
    });

    it("should have a correct number of eth when bot deposit is fractional", async () => {
      let amountToDeposit = Math.floor(value*4.7)

      await trader.botDeposit({from: accounts[bot], value: amountToDeposit})

      assert.equal(web3.eth.getBalance(trader.address).toNumber(),amountToDeposit);

      let promises = [
        trader.getBalance.call({from: accounts[player1]}),
        trader.getBalance.call({from: accounts[player2]}),
        trader.getBalance.call({from: accounts[bot]}),
        trader.getBalance.call({from: accounts[owner]})
      ]

      let amounts = await Promise.all(promises)
      let total = amounts.reduce((c,amount) => c + amount.toNumber(), 0);

      assert.equal(total, amountToDeposit);

    });
  })

});
