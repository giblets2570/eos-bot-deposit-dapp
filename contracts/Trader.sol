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
  uint private ownerAmount;
  address private botAccount;

  address[] private players;
  mapping(address => uint) private balances;

  modifier isPlayer() {
    for(uint i = 0; i < players.length; i++){
      if(msg.sender == players[i]) _;
    }
  }

  modifier isBot() {
    if(msg.sender == botAccount) _;
  }

  function Trader(address[] _owners, address _trading_account) {
    for(uint i = 0; i < _owners.length; i++){
      owners.push(_owners[i]);
      balances[_owners[i]] = 0;
    }
  }

  function getBalance() isPlayer public constant returns(uint balance) {
    return balances[msg.sender];
  }

  function totalAmountDecrease(amount) private {
    uint totalGiven = 0;
    for(uint i = 0; i < owners.length; i++){
      balances[owners[i]] = SafeMath.div(SafeMath.mul(balances[owners[i]], availableBalance), totalBalance)
      totalGiven += balances[owners[i]];
    }
    for(i = 0; i < players.length; i++){
      balances[players[i]] = SafeMath.div(SafeMath.mul(balances[players[i]], availableBalance), totalBalance)
      totalGiven += balances[players[i]];
    }
    uint leftover = amount - totalGiven;
    uint baseAmount = SafeMath.div(leftover,owners.length)
    balances[owners[0]] += leftover % owners.length
    for(uint i = 0; i < owners.length; i++){
      balances[owners[i]] += baseAmount
    }
  }

  function totalAmountIncrease(amount) private {
    
  }

  function botDeposit() isBot payable public {
    require(msg.value > 0);
    availableBalance = msg.value;
    // Check if total balance has shrunk
    if (availableBalance <= totalBalance) {
      totalAmountDecrease(availableBalance);
    }else {
      totalAmountIncrease(availableBalance)
    }
    totalBalance = availableBalance
  }

  // Function where the bot account deposits into the contract
  function botWithdrawal() isBot public {
    uint amount = availableBalance;
    availableBalance = 0;
    msg.sender.transfer(amount);
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
    if(!found) players.push(msg.sender);
    balances[msg.sender] = balance + msg.value;
  }
}