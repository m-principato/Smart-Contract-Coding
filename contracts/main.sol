// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//Making use of as much battle-tested code imports as possible to minimize bugs and possible attack vectors
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Main is ERC1155, IERC721Receiver, Pausable, Ownable, ERC1155Supply {
    using SafeMath for uint256; //using SafeMath library to avoid integer overflow-/underflow attacks
    using Counters for Counters.Counter; //using Counters library to safely increment a global counter

    Counters.Counter private _intIDcounter;

//Declarations
    
    //Custom Fractionalizer declarations:
    struct infoStorage {
            DepositInfo[] Deposit;
        }

    struct DepositInfo {
        address owner;
        
        address Ext_NFT_Address;
        uint256 Ext_NFT_ID;

        uint256 Int_NFT_ID;
        uint256 depositTimestamp;
        
        uint256 totalCO2O;
        uint256 fractions;
        bool fractionalized;
    }

    mapping(address => infoStorage) UserToDeposits;
    mapping(address => mapping (uint256 => uint256)) NftIndex;

    //Custom AMM declarations:
    mapping(uint256 => uint256) ID2AMMconstant;

    mapping(uint256 => uint256) ID2AMMfDeposits;
    mapping(uint256 => uint256) ID2AMMwDeposits;

    mapping(address => uint256) User2LPshares;
    mapping(address => uint256) User2wWei;

//Constructor

    constructor() ERC1155("") { 
        /*Placeholder*/
    }

//Custom modifiers:

    modifier fractionalized0(uint256 _Int_NFT_ID) {
        require(UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].fractionalized == false, "Token has already been fractionalized");
        _;
    }   

    modifier fractionalized1(uint256 _Int_NFT_ID) {
        require(UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].fractionalized == true, "Token has not yet been fractionalized");
        _;
    }  

    modifier NFTowner(uint256 _Int_NFT_ID) {
        require(UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].owner == msg.sender, "Only the owner of this NFT can access it");
        _;
    }

    modifier validAmountFraction(uint256 _amountFraction, uint256 _Int_NFT_ID) {
        require(balanceOf(msg.sender, _Int_NFT_ID) >= _amountFraction, "Insufficient fractions");
        require(_amountFraction >= 0, "Ammount cannot be Zero");
        _;
    }

    modifier activePool(uint256 _Int_NFT_ID) {
        require(ID2AMMfDeposits[_Int_NFT_ID] > 0, "Zero Liquidity...Wait until liquidity is provided");
        _;
    }

//Security functionalities:

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

//Operational functionalities

    //Custom fractionalizer functionalities:
    function DepositNFT(address _Ext_NFT_Address, uint256 _Ext_NFT_ID, uint256 _CO2O) external {
      
        ERC721(_Ext_NFT_Address).safeTransferFrom(msg.sender, address(this), _Ext_NFT_ID);

        DepositInfo memory newDeposit;

            newDeposit.owner = msg.sender;
            newDeposit.Ext_NFT_Address = _Ext_NFT_Address;
            newDeposit.Int_NFT_ID = _intIDcounter.current();
            newDeposit.Ext_NFT_ID = _Ext_NFT_ID;
            newDeposit.depositTimestamp = block.timestamp;
            newDeposit.totalCO2O = _CO2O;
            newDeposit.fractions = 0;
            newDeposit.fractionalized = false;
        
        NftIndex[_Ext_NFT_Address][_Ext_NFT_ID] = UserToDeposits[msg.sender].Deposit.length;

        _intIDcounter.increment();

        UserToDeposits[msg.sender].Deposit.push(newDeposit);
    }

    function getDepositInfo(address _Account, address _Ext_NFT_Address, uint256 _Ext_NFT_ID) external view returns (address, address, uint256, uint256, uint256, uint256, bool, uint256) {
 
        uint256 _NFTindex = NftIndex[_Ext_NFT_Address][_Ext_NFT_ID]; // Look up the deposit information using the NftIndex mapping

        DepositInfo storage deposit = UserToDeposits[_Account].Deposit[_NFTindex]; // Get the deposit information using the UserToDeposits mapping and the deposit index

        return (deposit.owner, deposit.Ext_NFT_Address, deposit.Ext_NFT_ID, deposit.Int_NFT_ID, deposit.depositTimestamp, deposit.totalCO2O, deposit.fractionalized, deposit.fractions); // Return the relevant information from the deposit
    }

    function WithdrawNFT(uint256 _Int_NFT_ID) external fractionalized0(_Int_NFT_ID) NFTowner(_Int_NFT_ID) {
        
        address _Ext_NFT_Address = UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].Ext_NFT_Address;
        uint256 _nftID =  UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].Ext_NFT_ID;

        delete UserToDeposits[msg.sender].Deposit[_Int_NFT_ID];

        ERC721(_Ext_NFT_Address).safeTransferFrom(address(this), msg.sender, _nftID);
    }

    function FractionalizeNFT(uint256 fractions, uint256 _Int_NFT_ID) external fractionalized0(_Int_NFT_ID) NFTowner(_Int_NFT_ID) {
       
        UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].fractionalized = true;
        UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].fractions = fractions;

        _mint(address(msg.sender), _Int_NFT_ID, fractions, "");
    }

    function UnifyFractions(uint256 _Int_NFT_ID) external fractionalized0(_Int_NFT_ID) {
        
        uint256 totalFractions = UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].fractions;
        require(balanceOf(msg.sender, _Int_NFT_ID) == totalFractions, "Insufficient fractions");
       
        UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].fractionalized = false;
        UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].fractions = 0;
        
        _burn(address(msg.sender), _Int_NFT_ID, totalFractions);
    }

    //Custom AMM functions:

    function provideLiq(uint256 _amountFraction, uint256 _Int_NFT_ID) external payable validAmountFraction(_amountFraction, _Int_NFT_ID) {
        require(msg.value >= 0, "Value cannot be Zero");
        User2wWei[msg.sender].add(msg.value);
        if(ID2AMMfDeposits[_Int_NFT_ID] == 0) { 
            User2LPshares[msg.sender].add(100);
            ID2AMMfDeposits[_Int_NFT_ID].add(100);
            ID2AMMwDeposits[_Int_NFT_ID].add(msg.value);
        } 
        else{              
            uint256 share_Fraction = ID2AMMfDeposits[_Int_NFT_ID].mul(_amountFraction).div(ID2AMMfDeposits[_Int_NFT_ID]);
            uint256 share_wWei = ID2AMMwDeposits[_Int_NFT_ID].mul(msg.value).div(ID2AMMwDeposits[_Int_NFT_ID]); 
            require(share_Fraction == share_wWei, "Equivalent value of tokens not provided");
        }

        
    }






//Overrides

    //Required override by solidity for safely receiving ERC721 tokens
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns(bytes4) {
        return this.onERC721Received.selector;
    } 
    //Required override to enable the pause function
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal whenNotPaused override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
