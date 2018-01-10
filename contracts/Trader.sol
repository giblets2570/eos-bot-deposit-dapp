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
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
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
  uint private totalBalance;
  uint private availableBalance;

  address[] private owners;
  address private botAccount;
  uint private ownerPercentGains;

  address[] private players;
  mapping(address => bool) private playersMap;
  mapping(address => uint) private balances;

  address[] private playersDuringTrade;
  mapping(address => uint) private playersDuringTradeBalances;

  bool private onTrade;

  modifier isOwner() {
    bool found = false;
    for(uint i = 0; i < owners.length; i++){
      if(msg.sender == owners[i]) {
        found = true;
        break;
      }
    }
    require(found);
    _;
  }

  modifier isPlayer() {
    bool found = playersMap[msg.sender];
    if(!found){
      for(uint i = 0; i < owners.length; i++){
        if(msg.sender == owners[i]){
          found = true;
          break;
        }
      }
    }
    require(found);
    _;
  }

  modifier isBot() {
    require(msg.sender == botAccount);
    _;
  }

  event TotalWinnings(uint winnings);
  event TradeMadeMoney(string str, uint amountBefore, uint amountAfter);
  event TradeLostMoney(string str, uint amountBefore, uint amountAfter);

  function Trader(address[] _owners, address _botAccount, uint _ownerPercentGains) public {
    require(_ownerPercentGains < 100);
    for(uint i = 0; i < _owners.length; i++){
      owners.push(_owners[i]);
      balances[_owners[i]] = 0;
    }
    botAccount = _botAccount;
    ownerPercentGains = _ownerPercentGains;
    onTrade = false;
  }

  function getBalance() isPlayer public constant returns(uint balance) {
    return balances[msg.sender];
  }

  function getTotalBalance() isOwner public constant returns(uint balance) {
    return totalBalance;
  }

  function getAvailableBalance() isOwner public constant returns(uint balance) {
    return availableBalance;
  }

  // Function where the bot account withdraws the contract
  function botWithdrawal() isBot public {
    uint amount = availableBalance;
    availableBalance = 0;
    onTrade = true;
    msg.sender.transfer(amount);
  }

  // Function where the player withdraws from the contract
  // Should probably allow them to withdraw bits of their balances
  function playerWithdrawal() isPlayer public {
    // Make sure not in a current trade
    require(!onTrade);
    uint amount = balances[msg.sender];
    require(availableBalance > amount);
    balances[msg.sender] = 0;
    msg.sender.transfer(amount);
    totalBalance = SafeMath.sub(totalBalance, amount);
    availableBalance = SafeMath.sub(availableBalance, amount);
  }

  // This will add the deposits to the users that
  // Deposited during the trade
  function addOnTradeDeposits() private {
    uint value;
    for(uint i = playersDuringTrade.length; i > 0; i--) {
      value = playersDuringTradeBalances[playersDuringTrade[i-1]];
      balances[playersDuringTrade[i-1]] = SafeMath.add(balances[playersDuringTrade[i-1]], value);
      delete playersDuringTradeBalances[playersDuringTrade[i-1]];
      delete playersDuringTrade[i-1];
      totalBalance = SafeMath.add(totalBalance, value);
      availableBalance = SafeMath.add(availableBalance, value);
    }
  }

  // When the total amount decreases, we all share in the losses
  function totalAmountDecrease(uint amount) private {
    uint totalGiven = 0;
    for(uint i = 0; i < owners.length; i++){
      balances[owners[i]] = SafeMath.div(SafeMath.mul(balances[owners[i]], amount), totalBalance);
      totalGiven = SafeMath.add(totalGiven,balances[owners[i]]);
    }
    for(i = 0; i < players.length; i++){
      balances[players[i]] = SafeMath.div(SafeMath.mul(balances[players[i]], amount), totalBalance);
      totalGiven = SafeMath.add(totalGiven,balances[players[i]]);
    }

    // This just to fix rounding errors
    uint leftover = SafeMath.sub(amount, totalGiven);
    uint baseAmount = SafeMath.div(leftover,owners.length);
    balances[owners[0]] = SafeMath.add(balances[owners[0]],leftover % owners.length);
    for(i = 0; i < owners.length; i++){
      balances[owners[i]] = SafeMath.add(balances[owners[i]],baseAmount);
    }
  }

  function calculatePlayerWinnings(uint winnings, uint ownersBalance) private constant returns(uint playersWinnings) {
    uint ownersWinnings = SafeMath.div(
      SafeMath.mul(winnings,ownersBalance), 
      totalBalance
    );
    uint playersWinningsBeforeCut = SafeMath.sub(winnings,ownersWinnings);
    playersWinnings = SafeMath.div(
      SafeMath.mul(playersWinningsBeforeCut, ownerPercentGains), 
      100
    );
  }

  // When the total amount increases, the owners will take
  // ownerPercentGains % of the winnings for the round
  function totalAmountIncrease(uint amount) private {
    uint ownersBalance = 0;
    for(uint i = 0; i < owners.length; i++){
      ownersBalance = SafeMath.add(ownersBalance, balances[owners[i]]);
    }
    uint playersBalance = SafeMath.sub(totalBalance, ownersBalance);
    uint winnings = SafeMath.sub(amount,totalBalance);
    uint playersWinnings = calculatePlayerWinnings(winnings, ownersBalance);
    uint ownersWinnings = SafeMath.sub(winnings, playersWinnings);

    uint newBalance;
    uint oldBalance;
    uint totalGiven = 0;

    for(i = 0; i < players.length; i++){
      oldBalance = balances[players[i]];
      newBalance = SafeMath.add(
        oldBalance,
        SafeMath.div(
          SafeMath.mul(
            playersWinnings,
            oldBalance
          ), 
          playersBalance
        )
      );
      balances[players[i]] = newBalance;
      totalGiven = SafeMath.add(totalGiven,newBalance);
    }    

    for(i = 0; i < owners.length; i++){
      if(ownersBalance == 0) {
        uint ratio = SafeMath.div(1000,owners.length);
        newBalance = SafeMath.div(
          SafeMath.mul(
            ownersWinnings,
            ratio
          ),
          1000
        );
      }else{
        oldBalance = balances[owners[i]];
        newBalance = SafeMath.add(
          oldBalance,
          SafeMath.div(
            SafeMath.mul(
              ownersWinnings,
              oldBalance
            ),
            ownersBalance
          )
        );
      }
      balances[owners[i]] = newBalance;
      totalGiven = SafeMath.add(totalGiven,newBalance);
    }

    // This just to fix rounding errors
    uint leftover = SafeMath.sub(amount, totalGiven);
    uint baseAmount = SafeMath.div(leftover,owners.length);
    balances[owners[0]] = SafeMath.add(balances[owners[0]],leftover % owners.length);
    for(i = 0; i < owners.length; i++){
      balances[owners[i]] = SafeMath.add(balances[owners[i]],baseAmount);
    }
  }

  // What happends when the bot deposits money into the smart contract
  function botDeposit() isBot payable public {
    require(msg.value > 0);
    // Check if total balance has shrunk
    if (msg.value <= totalBalance) {
      TradeLostMoney("I lost money", totalBalance, msg.value);
      totalAmountDecrease(msg.value);
    }else {
      TradeMadeMoney("I made money", totalBalance, msg.value);
      totalAmountIncrease(msg.value);
    }
    availableBalance = msg.value;
    totalBalance = msg.value;
    addOnTradeDeposits();
    onTrade = false;
  }

  // Function where people deposit into the smart contract
  function() payable {
    require(msg.value > 0);
    uint balance = 0;
    bool found = false;
    for(uint i = 0; i < players.length; i++){
      if(msg.sender == players[i]) {
        found = true;
        balance = balances[msg.sender];
      }
    }
    if(!found) {
      players.push(msg.sender);
      playersMap[msg.sender] = true;
    }

    // Need to figure out what happens if they
    // Deposit while the bot is in a trade
    if(onTrade){
      // If they make multiple deposits
      if(playersDuringTradeBalances[msg.sender] > 0){
        playersDuringTradeBalances[msg.sender] = SafeMath.add(playersDuringTradeBalances[msg.sender],msg.value);
      }else{
        playersDuringTrade.push(msg.sender);
        playersDuringTradeBalances[msg.sender] = msg.value;
      }
    }else{
      balances[msg.sender] = SafeMath.add(balance, msg.value);
      totalBalance = SafeMath.add(totalBalance, msg.value);
      availableBalance = SafeMath.add(availableBalance, msg.value);
    }
  }
}