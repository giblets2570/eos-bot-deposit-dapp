var Trader = artifacts.require("./Trader.sol");

module.exports = function(deployer, network, accounts) {
  console.log(accounts.slice(0,2))
  deployer.deploy(Trader, accounts.slice(0,2), accounts[0], 60);
};
