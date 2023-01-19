// SPDX-License-Identifier: GPL-3.0

////// Disclaimer
// This contract is ready to handle transactions with DAI-tokens,
// for testing purposes that feature has been commented out
//////


pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface DaiToken {                                                                                //DAI interface to allow for DAI transfers
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
    function balanceOf(address guy) external view returns (uint);
}


contract GarageDAO is ERC1155 {
    uint256 public constant OG_DAO = 0;                                                                 // initial token IDs for future reference
    uint256 public constant OG_M350SL = 1;
    uint256 public nextProjectID = 1;                                                                   // ID of next token Project 
    uint256 public liquidityPool;                                                                       // see how much money is in the liquidity pool
    address public owner;   
    IERC20 public daiInstance;                                                                          //address of DAI smart contract

    DaiToken public daiToken;
    address public governance;   
    mapping(uint256 => uint256) public tokenPrice;

    modifier onlyGovernance() {                                                                         // key functionalities will only be callable by the governance
        require(msg.sender == governance, "only governance can call this");
        _;
    }
    constructor(/*IERC20 _daiInstance*/) ERC1155("") {                                                  // set daiInstance = address of DAI smart contract on corresponding chain (example 0x65600c50ea42e225368ded6c3789a539284aa62c on ropsten testnet)
        owner = msg.sender;                                                                             // this contract is owned by an external entity (like a juristische Person in germany), to allow for the legal backing of assets between the real world and this contract
        governance = address(this);                                                                     // this contract governs itself (DAO)  
        capitalIncrease(1000);                                                                          // emit 1.000 OG_DAO at construction
        emitNewCarToken(100);                                                                           // emit 100 OG_M350SL at construction 
        setTokenPrice(OG_DAO, 400);                                                                     // initial price of OG_DAO tokens is set to 0.4 eth ( 400 finney or roughly 1.000 €)
        setTokenPrice(OG_M350SL, 150);                                                                  // price of OG_M350SL token is set to 0.15 eth (150 finney or roughly 400€)
//        setTokenPrice(OG_DAO, 1000);                                                                  // set DAI prices
//        setTokenPrice(OG_M350SL, 400);                                                                // set DAI prices
//        daiInstance = _daiInstance;                                                                   // set DAI instance
    }

    function capitalIncrease(uint256 amountNewShares) private returns(bool) {                         // internal & onlyGovernance are redundant as long as governance = address(this)
        _mint(governance, OG_DAO, amountNewShares, "");                                               // "amountNewShares" determines how many new OG_DAOs are minted to the DAOs address
        setApprovalForAll(address(this), true);                                                       // necessary function for future governance of ERC-1155 tokens (so tokens can be sent on behalf of someone)                                                
        return true;
    }

    function capitalReduction(uint256 amountSharesDecreased) private returns(bool) {                  // internal & onlyGovernance are redundant as long as governance = address(this)
        _burn(governance, OG_DAO, amountSharesDecreased);                                             // "amountSharesDecreased" determines how many OG_DAOs are burned from the DAOs address
        return true;
    }

    function emitNewCarToken(uint256 fractions) private returns(bool) {             
        _mint(governance, nextProjectID, 1 * fractions, "");                                          // "fractions" determines into how many parts the NFT is split
        setApprovalForAll(address(this), true);                                                       // necessary function for future governance of ERC-1155 tokens (so tokens can be sent on behalf of someone)
        nextProjectID = nextProjectID + 1;                                                            // increase next project ID                     
        return true;
    }

    function burnCarTokens(uint256 tokenID, uint256 amount) private returns(bool) {                   // function to burn car-tokens, for example when a car is sold, tokens have to be transferred to the DAO-contract before they can be burned
        _burn(msg.sender, tokenID, amount);
        return true;
    }

    function setTokenPrice(uint256 id, uint256 price) private returns(bool) {                         // internal & onlyGovernance are redundant as long as governance = address(this)
        tokenPrice[id] = price;                                                                       // set price for individual token
        return true;
    }

    function purchaseOGDAO(uint256 amount) public payable returns(bool) {
        require(msg.value >= (amount * tokenPrice[OG_DAO] * 1e15), "Transaction value not sufficient to buy amount of tokens");    // enough money has to be sent (multiply with 1e15 to put price in finneys instead of ether)
        require(balanceOf(address(this), OG_DAO) >= amount, "Less than requested amount of OG_DAO tokens available");       // enough tokens have to be left
        require(msg.sender != address(0x0));                                                                                // require sender address to not be zero address (to not burn tokens inadvertently)         
        _safeTransferFrom(address(this), msg.sender, OG_DAO, amount, "");                                                   // transfer OG_DAO tokens from the DAO to msg.sender
        liquidityPool = liquidityPool + msg.value;                                                                          // add currency to liquidity pool
        return true;
    }

    function purchaseCarToken(uint256 id, uint256 amount) public payable returns(bool) {                                    // for the ICO id == 1 
        require(id != 0, "please purchase OG_DAO tokens through seperate function");                                        // OG_DAO tokens can only be purchased through seperate function to avoid confusion
        require(msg.value >= amount * tokenPrice[id]  * 1e15, "Transaction amount not sufficient");                         // (multiply with 1e15 to put price in finneys instead of ether)
        require(balanceOf(address(this), id) >= amount, "Less than requested amount of tokens available");                  // enough tokens have to be left
        require(msg.sender != address(0x0));                                                                                // require sender address to not be zero address (to not burn tokens inadvertently)                                                                                        
        _safeTransferFrom(address(this), msg.sender, id, amount, "");                                                       // transfer car tokens from the DAO to msg.sender
        liquidityPool = liquidityPool + msg.value;                                                                          // add currency to liquidity pool
        return true;
    }
/*
// functions that accept DAI instead of ether
    function purchaseOGDAOinDAI(uint256 amount) public payable returns(bool) {
        daiAmount = amount * tokenPrice[OG_DAO];                                                                            // convert price and tokenamount to DAI
        bool success = daiInstance.transferFrom(msg.sender, address(this), daiAmount);                                      // see if DAI transaction has gone through on DAI smart contracts
        require(success, "buy failed");                                                                                     // require successful DAI transaction
        liquidityPool = liquidityPool + daiAmount;                                                                          // add currency to liquidity pool
        _safeTransferFrom(address(this), msg.sender, OG_DAO, amount, "");                                                   // transfer OG_DAO tokens from the DAO to msg.sender
        return true;
    }
    function purchaseCarTokeninDAI(uint256 id, uint256 amount) public payable returns(bool) { 
        daiAmount = amount * tokenPrice[id];                                                                                // convert price and tokenamount to DAI
        bool success = daiInstance.transferFrom(msg.sender, address(this), daiAmount);                                      // see if DAI transaction has gone through on DAI smart contracts
        require(success, "buy failed");                                                                                     // require successful DAI transaction                      
        liquidityPool = liquidityPool + daiAmount;                                                                          // add currency to liquidity pool                                                                                        
        _safeTransferFrom(address(this), msg.sender, id, amount, "");                                                       // transfer car tokens from the DAO to msg.sender                                               
        return true;
    }*/

}
