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

 contract WBNB_MINER {

    IERC20 public token_WBNB;
    address WBNB_ADDRESS = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c); //WBNB 
    uint256 public EGGS_TO_HATCH_1MINERS=760320;
    uint256 PSN=10000;
    uint256 PSNH=5000;
    bool public initialized=false;
    uint256 public earlyWithdrawTax=20; //percent
    bool public choke=false;
    bool public warmupComplete=false;
    address public ceoAddress;
    address public ceoAddress2;
    mapping (address => uint256) public hatcheryMiners;
    mapping (address => uint256) public claimedEggs;
    mapping (address => uint256) public lastHatch;
    mapping (address => address) public referrals;
    mapping (address => uint256) public withdrawals; // everything that goes out by user
    mapping (address => uint256) public deposits; // everything the user puts in
    uint256 public marketEggs;
    
    address NULL_ADDRESS = address(0x0000000000000000000000000000000000000000);
    
    constructor(){
        
        token_WBNB = IERC20(WBNB_ADDRESS);
        
        ceoAddress=msg.sender;
        ceoAddress2=address(0xc0A8cE646CcbB94689f28B27Ed98ED1b3E49e2Bb);
    }
    
    function hatchEggs(address ref) public {
        require(initialized);
        if(ref == msg.sender) {
            ref = NULL_ADDRESS;
        }
        if(referrals[msg.sender] == NULL_ADDRESS && referrals[msg.sender]!=msg.sender) {
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
        token_WBNB.transfer(ceoAddress, fee2);
        token_WBNB.transfer(ceoAddress2, fee-fee2);
        
        uint256 withDrawAmount = SafeMath.sub(eggValue,fee);
        token_WBNB.transfer(address(msg.sender), withDrawAmount);
        withdrawals[address(msg.sender)] += withDrawAmount;
    }
    function buyEggs(address ref, uint256 amount) public {
        require(initialized);
        
        if(choke == true && msg.sender != ceoAddress && msg.sender != ceoAddress2){
            // anti-sniper: while miner not public, only the devs are able to fill the market. snipers-bots pay 100% penalty tax
            uint256 fee = (amount / 2);
            token_WBNB.transferFrom(address(msg.sender), address(this), amount);
            token_WBNB.transfer(ceoAddress, fee);
            token_WBNB.transfer(ceoAddress2, fee);
        }else{
            token_WBNB.transferFrom(address(msg.sender), address(this), amount);
            deposits[address(msg.sender)] += amount;
            
            uint256 balance = token_WBNB.balanceOf(address(this));
            uint256 eggsBought=calculateEggBuy(amount,SafeMath.sub(balance,amount));
            eggsBought=SafeMath.sub(eggsBought,devFee(eggsBought));
            uint256 fee=devFee(amount);
            uint256 fee2=fee/2;
            token_WBNB.transfer(ceoAddress, fee2);
            token_WBNB.transfer(ceoAddress2, fee-fee2);
            claimedEggs[msg.sender]=SafeMath.add(claimedEggs[msg.sender],eggsBought);
            hatchEggs(ref);
        }
    }
    function withdrawInvest() public{
        uint256 myInvest = deposits[msg.sender];
        uint256 currentMiners = hatcheryMiners[msg.sender];
        if(myInvest > 0 && currentMiners > 0){
            uint256 contractBalance = token_WBNB.balanceOf(address(this));
            
            uint256 myInvestWithoutFees = myInvest / 100 * (100 - earlyWithdrawTax); // 20% exit fee
            if(contractBalance > myInvestWithoutFees){
                token_WBNB.transfer(msg.sender, myInvestWithoutFees);
                
                deposits[msg.sender] = 0;
                withdrawals[msg.sender] += myInvestWithoutFees;
                hatcheryMiners[msg.sender] = 0;
                claimedEggs[msg.sender] = 0;
                lastHatch[msg.sender] = 0;
            }
        }
    }
    
    function withdrawInvestPossible() public view returns(bool){
        uint256 myInvest = deposits[msg.sender];
        uint256 currentMiners = hatcheryMiners[msg.sender];
        if(myInvest > 0 && currentMiners > 0){
            uint256 contractBalance = token_WBNB.balanceOf(address(this));
            uint256 myInvestWithoutFees = myInvest / 100 * (100 - earlyWithdrawTax); // 20% exit fee
            if(contractBalance > myInvestWithoutFees){
                return true;
            }
        }   
        return false;
    }
    //magic trade balancing algorithm
    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) public view returns(uint256) {
        //(PSN*bs)/(PSNH+((PSN*rs+PSNH*rt)/rt));
        return SafeMath.div(SafeMath.mul(PSN,bs),SafeMath.add(PSNH,SafeMath.div(SafeMath.add(SafeMath.mul(PSN,rs),SafeMath.mul(PSNH,rt)),rt)));
    }
    function calculateEggSell(uint256 eggs) public view returns(uint256) {
        return calculateTrade(eggs,marketEggs,token_WBNB.balanceOf(address(this)));
    }
    function calculateEggBuy(uint256 eth,uint256 contractBalance) public view returns(uint256) {
        return calculateTrade(eth,contractBalance,marketEggs);
    }
    function calculateEggBuySimple(uint256 eth) public view returns(uint256){
        return calculateEggBuy(eth,token_WBNB.balanceOf(address(this)));
    }
    function devFee(uint256 amount) public pure returns(uint256){
        return SafeMath.div(SafeMath.mul(amount,5),100);
    }
    function SetEarlyWithdrawTax(uint256 taxPercent) public {
        if(msg.sender == ceoAddress || msg.sender == ceoAddress2){
            require(initialized==true);
            earlyWithdrawTax = taxPercent;
        }
    }
    function EngineCold(uint256 amount) public {
        // anti-sniper while market gets initial fill to provide healthy envirnoment
        require(warmupComplete==false); // only possible once
        if(msg.sender == ceoAddress || msg.sender == ceoAddress2){
            token_WBNB.transferFrom(address(msg.sender), address(this), amount);
            require(initialized==true);
            choke = true;
        }
    }
    
    function EngineWarm(uint256 amount) public {
        if(msg.sender == ceoAddress || msg.sender == ceoAddress2){
            token_WBNB.transferFrom(address(msg.sender), address(this), amount);
            require(choke==true);
            choke = false; // anti-snier off
            warmupComplete = true; // engine warmup complete. choke cannot get activated a 2nd time 
        }
    }
    function seedMarket(uint256 amount) public {
        token_WBNB.transferFrom(address(msg.sender), address(this), amount);
        require(marketEggs==0);
        initialized=true;
        marketEggs=76032000000;
    }
    function getBalance() public view returns(uint256) {
        return token_WBNB.balanceOf(address(this));
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
