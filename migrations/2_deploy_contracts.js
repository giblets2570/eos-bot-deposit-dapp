var Trader = artifacts.require("./Trader.sol");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(Trader);
};
