pragma solidity ^0.4.18;

library SafeMath {
  function mul(uint a, uint b) internal pure returns (uint) {
    if (a == 0) {
      return 0;
    }
    uint c = a * b;
    assert(c / a == b);
    return c;
  }
  function div(uint a, uint b) internal pure returns (uint) {
    uint c = a / b;
    return c;
  }
  function sub(uint a, uint b) internal pure returns (uint) {
    assert(b <= a);
    return a - b;
  }
  function add(uint a, uint b) internal pure returns (uint) {
    uint c = a + b;
    assert(c >= a);
    return c;
  }
}

contract Trader {
  uint private maxBalance;
  uint private previousBalance;
  uint private playerPercentGains;
  bool private onTrade;

  address private botAccount;
  address[] private owners;
  address[] private players;
  mapping(address => bool) private ownersMap;
  mapping(address => bool) private usersMap;
  mapping(address => uint) private balances;
  mapping(address => uint) private duringTradeBalances;

  modifier isOwner() {
    require(ownersMap[msg.sender]);
    _;
  }
  modifier isUser() {
    require(usersMap[msg.sender]);
    _;
  }
  modifier isBot() {
    require(msg.sender == botAccount);
    _;
  }
  function Trader(address[] _owners, address _botAccount, uint _playerPercentGains, uint _maxBalance) public {
    require(_playerPercentGains < 100);
    botAccount = _botAccount;
    bool botIsOwner = false;
    for(uint i = 0; i < _owners.length; i++){
      owners.push(_owners[i]);
      ownersMap[_owners[i]] = true;
      usersMap[_owners[i]] = true;
      balances[_owners[i]] = 0;
      botIsOwner = botIsOwner || (_owners[i] == _botAccount);
    }
    require(botIsOwner);
    playerPercentGains = _playerPercentGains;
    maxBalance = _maxBalance;
    onTrade = false;
  }
  function getBalance() isUser public constant returns(uint balance) {
    return balances[msg.sender];
  }
  function getMaxBalance() isOwner public constant returns(uint balance) {
    return maxBalance;
  }
  function setMaxBalance(uint balance) isOwner public {
    maxBalance = balance;
  }
  function addPlayer(address player) isOwner public {
    usersMap[player] = true;
    players.push(player);
  }
  // Function where the bot account withdraws the contract
  function botWithdrawal() isBot public {
    onTrade = true;
    previousBalance = this.balance;
    msg.sender.transfer(this.balance);
  }
  // Function where the player withdraws from the contract
  // If amount is 0 then withdraw full amount
  function userWithdrawal(uint amount) isUser public {
    require(!onTrade);
    require(amount <= balances[msg.sender]);
    if(amount == 0){
      amount = balances[msg.sender];
    }
    balances[msg.sender] = SafeMath.sub(balances[msg.sender], amount);
    msg.sender.transfer(amount);
  }
  // When the total amount decreases, we all share in the losses
  function totalAmountDecrease(uint amount) private {
    uint totalGiven = 0;
    address user;
    for(uint i = 0; i < players.length + owners.length; i++){
      user = players[i % players.length];
      if(i >= players.length) user = owners[i % players.length];
      balances[user] = SafeMath.div(
        SafeMath.mul(balances[user], amount), 
        previousBalance
      );
      totalGiven = SafeMath.add(totalGiven,balances[user]);
    }
    uint leftovers = SafeMath.sub(amount, totalGiven);
    giveLeftovers(leftovers);
  }
  function calculatePlayerTotalWinnings(uint winnings, uint ownersBalance) private constant returns(uint playersWinnings) {
    if(previousBalance > 0) {
      uint ownersWinnings = SafeMath.div(
        SafeMath.mul(winnings,ownersBalance), 
        previousBalance
      );
      uint playersWinningsBeforeCut = SafeMath.sub(winnings,ownersWinnings);
      playersWinnings = SafeMath.div(
        SafeMath.mul(playersWinningsBeforeCut, playerPercentGains), 
        100
      );
    }else{
      playersWinnings = SafeMath.div(
        SafeMath.mul(winnings, playerPercentGains), 
        100
      );
    }
  }
  function calculateUserWinnings(address user, uint usersWinnings, uint usersBalance) private constant returns(uint winnings){
    if(balances[user] == 0){
      winnings = 0;
    }else{
      winnings = SafeMath.add(
        balances[user],
        SafeMath.div(
          SafeMath.mul(usersWinnings, balances[user]),
          usersBalance
        )
      );
    }
  }
  function addDuringTradeBalance(address user) private {
    balances[user] = SafeMath.add(balances[user], duringTradeBalances[user]);
    duringTradeBalances[user] = 0;
  }
  // When the total amount increases, the owners will take
  // (100 - playerPercentGains) % of the winnings for the round
  function totalAmountIncrease(uint amount) private {
    uint winnings = SafeMath.sub(amount,previousBalance);
    uint ownersBalance = 0;
    for(uint i = 0; i < owners.length; i++){
      ownersBalance = SafeMath.add(ownersBalance, balances[owners[i]]);
    }
    uint playersBalance = SafeMath.sub(previousBalance, ownersBalance);
    uint playersWinnings = calculatePlayerTotalWinnings(winnings, ownersBalance);
    uint ownersWinnings = SafeMath.sub(winnings, playersWinnings);
    uint totalGiven = 0;
    for(i = 0; i < players.length; i++){
      balances[players[i]] = calculateUserWinnings(players[i], playersWinnings, playersBalance);
      totalGiven = SafeMath.add(totalGiven,balances[players[i]]);
      addDuringTradeBalance(players[i]);
    }
    for(i = 0; i < owners.length; i++){
      balances[owners[i]] = calculateUserWinnings(owners[i], ownersWinnings, ownersBalance);
      totalGiven = SafeMath.add(totalGiven,balances[owners[i]]);
      addDuringTradeBalance(owners[i]);
    }
    uint leftovers = SafeMath.sub(amount, totalGiven);
    giveLeftovers(leftovers);
  }
  function giveLeftovers(uint leftovers) private {
    if(leftovers > 0){
      uint baseAmount = SafeMath.div(leftovers,owners.length);
      uint randomNumber = uint(block.blockhash(block.number-1))%owners.length;
      balances[owners[randomNumber]] = SafeMath.add(balances[owners[randomNumber]],leftovers % owners.length);
      for(uint i = 0; i < owners.length; i++){
        balances[owners[i]] = SafeMath.add(balances[owners[i]],baseAmount);
      }
    }
  }
  // What happends when the bot deposits money into the smart contract after trade
  function botDeposit() isBot payable public {
    require(onTrade);
    require(msg.value > 0);
    if (msg.value <= previousBalance) {
      totalAmountDecrease(msg.value);
    }else {
      totalAmountIncrease(msg.value);
    }
    onTrade = false;
  }
  // Function where people deposit into the smart contract
  function() payable public {
    require(!onTrade);
    require(usersMap[msg.sender]);
    require(msg.value > 0);
    require(msg.value + this.balance <= maxBalance);
    balances[msg.sender] = SafeMath.add(balances[msg.sender], msg.value);
  }
}