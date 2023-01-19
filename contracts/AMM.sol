// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ConstantFunctionMarketMaker {
   
    using SafeMath for uint256; //using SafeMath Lib to avoid int overflow-/underflow attacks

    address owner;        // Stores the owner account

    uint256 totalShares;  // Stores the total amount of liquidity shares issued for the pool
    uint256 totalToken1;  // Stores the amount of Token1 locked in the pool
    uint256 totalToken2;  // Stores the amount of Token2 locked in the pool
    uint256 k;            // Constant used to determine price algorithmically -> totalToken1*totalToken2 = k

    uint256 constant PRECISION = 1_000_000;  // Precision of 6 digits (decimals)

    mapping(address => uint256) shares;         // Stores the liquidity share of each provider
    mapping(address => uint256) token1Balance;  // Stores the available token1 balance for users 
    mapping(address => uint256) token2Balance;  // Stores the available token2 balance for users 

    constructor(){
        owner = msg.sender; //Initial sender of contract = owner
    }

    //Create modiifier for admin rights
    modifier onlyOwner(){
        require(msg.sender == owner, "Insufficient permission");
        _;
    }

    // Create modifier for checks that quantity is non-zero and the user has enough balance
    modifier validAmountCheck(mapping(address => uint256) storage _balance, uint256 _qty) {
        require(_qty > 0, "Amount cannot be zero!");
        require(_qty <= _balance[msg.sender], "Insufficient balance");
        _;
    }
    
    // Create modifier for liquidity checks when withdrawing that otherwise restricts withdrawal and swap feature till liquidity is added
    modifier activePool() {
        require(totalShares > 0, "Zero Liquidity...Wait until liquidity is provided");
        _;
    }
    
    // Returns the balance of the user
    function getBalance() external view returns(uint256 amountToken1, uint256 amountToken2, uint256 myShare) {
        amountToken1 = token1Balance[msg.sender];
        amountToken2 = token2Balance[msg.sender];
        myShare = shares[msg.sender];
    }
    
    // Returns the total amount of tokens locked in the pool and the corresponding total shares
    function getPoolDetails() external view returns(uint256, uint256, uint256) {
        return (totalToken1, totalToken2, totalShares);
    }

    // Returns amount of Token1 required when providing liquidity with _amountToken2 quantity of Token2
    function getEquivalentToken1Estimate(uint256 _amountToken2) public view activePool returns(uint256 reqToken1) {
        reqToken1 = totalToken1.mul(_amountToken2).div(totalToken2);
    }

    // Returns amount of Token2 required when providing liquidity with _amountToken1 quantity of Token1
    function getEquivalentToken2Estimate(uint256 _amountToken1) public view activePool returns(uint256 reqToken2) {
        reqToken2 = totalToken2.mul(_amountToken1).div(totalToken1);
    }

    // Adding new liquidity in the pool
    function provide(uint256 _amountToken1, uint256 _amountToken2) external validAmountCheck(token1Balance, _amountToken1) validAmountCheck(token2Balance, _amountToken2) returns(uint256 share) {
        if(totalShares == 0) { // When first providing liquidity, 100 Shares are issued
            share = 100*PRECISION;
        } else{               // Else the share is calculated as follows 
            uint256 share1 = totalShares.mul(_amountToken1).div(totalToken1); //totalShares*(amountToken1/totalToken1)
            uint256 share2 = totalShares.mul(_amountToken2).div(totalToken2); //totalShares*(amountToken2/totalToken2)
            require(share1 == share2, "Equivalent value of tokens not provided..."); // Because amountToken1/totalToken1 must be equal to amountToken2/totalToken2
            share = share1;
        }

        require(share > 0, "Error...supplied liquidity cannot be zero!"); //require that any value is supplied
        token1Balance[msg.sender] -= _amountToken1; 
        token2Balance[msg.sender] -= _amountToken2;
        //Subtract first, then add to avoid re-entrency attacks
        totalToken1 += _amountToken1;
        totalToken2 += _amountToken2;
        k = totalToken1.mul(totalToken2); //CFMM Formular for AMMs: p*q=m -> here: totalToken1*totalToken2=k

        totalShares += share; //Increment total shares by newly issued shares
        shares[msg.sender] += share; //credit shares to liquidity provider
    }

    // Returns the estimate of Token1 & Token2 that will be released on burning a given count of shares
    function getWithdrawEstimate(uint256 _share) public view activePool returns(uint256 amountToken1, uint256 amountToken2) {
        require(_share <= totalShares, "Share should be less than totalShare"); // formal check against bogus requests
        amountToken1 = _share.mul(totalToken1).div(totalShares);
        amountToken2 = _share.mul(totalToken2).div(totalShares);
    }

    // Removes liquidity from the pool and releases corresponding Token1 & Token2 to the withdrawer
    function withdraw(uint256 _share) external activePool validAmountCheck(shares, _share) returns(uint256 amountToken1, uint256 amountToken2) {
        (amountToken1, amountToken2) = getWithdrawEstimate(_share);
        
        shares[msg.sender] -= _share;
        totalShares -= _share;

        totalToken1 -= amountToken1;
        totalToken2 -= amountToken2;
        k = totalToken1.mul(totalToken2);

        token1Balance[msg.sender] += amountToken1;
        token2Balance[msg.sender] += amountToken2;
    }

    // Returns the amount of Token2 that the user will get when swapping a given amount of Token1 for Token2
    function getSwapToken1Estimate(uint256 _amountToken1) public view activePool returns(uint256 amountToken2) {
        uint256 token1After = totalToken1.add(_amountToken1);
        uint256 token2After = k.div(token1After);
        amountToken2 = totalToken2.sub(token2After);

        // To ensure that Token2's pool is not completely depleted leading to inf:0 ratio
        if(amountToken2 == totalToken2) amountToken2--;
    }
    
    // Returns the amount of Token1 that the user should swap to get _amountToken2 in return
    function getSwapToken1EstimateGivenToken2(uint256 _amountToken2) public view activePool returns(uint256 amountToken1) {
        require(_amountToken2 < totalToken2, "Insufficient pool balance");
        uint256 token2After = totalToken2.sub(_amountToken2);
        uint256 token1After = k.div(token2After);
        amountToken1 = token1After.sub(totalToken1);
    }

    // Swaps given amount of Token1 to Token2 using algorithmic price determination
    function swapToken1(uint256 _amountToken1) external activePool validAmountCheck(token1Balance, _amountToken1) returns(uint256 amountToken2) {
        amountToken2 = getSwapToken1Estimate(_amountToken1);

        token1Balance[msg.sender] -= _amountToken1;
        totalToken1 += _amountToken1;
        totalToken2 -= amountToken2;
        token2Balance[msg.sender] += amountToken2;
    }

    // Returns the amount of Token2 that the user will get when swapping a given amount of Token1 for Token2
    function getSwapToken2Estimate(uint256 _amountToken2) public view activePool returns(uint256 amountToken1) {
        uint256 token2After = totalToken2.add(_amountToken2);
        uint256 token1After = k.div(token2After);
        amountToken1 = totalToken1.sub(token1After);

        // To ensure that Token1's pool is not completely depleted leading to inf:0 ratio
        if(amountToken1 == totalToken1) amountToken1--;
    }
    
    // Returns the amount of Token2 that the user should swap to get _amountToken1 in return
    function getSwapToken2EstimateGivenToken1(uint256 _amountToken1) public view activePool returns(uint256 amountToken2) {
        require(_amountToken1 < totalToken1, "Insufficient pool balance");
        uint256 token1After = totalToken1.sub(_amountToken1);
        uint256 token2After = k.div(token1After);
        amountToken2 = token2After.sub(totalToken2);
    }

    // Swaps given amount of Token2 to Token1 using algorithmic price determination
    function swapToken2(uint256 _amountToken2) external activePool validAmountCheck(token2Balance, _amountToken2) returns(uint256 amountToken1) {
        amountToken1 = getSwapToken2Estimate(_amountToken2);

        token2Balance[msg.sender] -= _amountToken2;
        totalToken2 += _amountToken2;
        totalToken1 -= amountToken1;
        token1Balance[msg.sender] += amountToken1;
    }

    //Create faucet for demonstration purposes 
    function faucet(uint256 _amountToken1, uint256 _amountToken2) external onlyOwner {
        token1Balance[msg.sender] = _amountToken1;
        token2Balance[msg.sender] = _amountToken2;
    }
}
