// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//Making use of as much battle-tested code imports as possible to minimize bugs and possible attack vectors
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Main is ERC1155, IERC721Receiver, Pausable, Ownable, ERC1155Burnable, ERC1155Supply {
    using SafeMath for uint256; //using SafeMath Library to avoid integer overflow-/underflow attacks
    using Counters for Counters.Counter;

    Counters.Counter private _intIDcounter;

//Custom Fractionalizer declarations
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


    constructor() ERC1155("") { 
        //Placeholder//
    }

//Custom modifiers:

    modifier fractionalized0(uint256 _Int_NFT_ID) {
        require(UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].fractionalized == false, "Token has not been fractionalized yet");
        _;
    }   

    modifier fractionalized1(uint256 _Int_NFT_ID) {
        require(UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].fractionalized == true, "Token already has been fractionalized");
        _;
    }  

    modifier NFTowner(uint256 _Int_NFT_ID) {
        require(UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].owner == msg.sender, "Only the owner of this NFT can access it");
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

    //ERC1155 standard functionalities:
    function mint(address account, uint256 id, uint256 amount, bytes memory data) private {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) private {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal whenNotPaused override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    //Custom fractionalizer functionalities:
    function DepositNFT(address NFTaddress, uint256 Ext_NFT_ID, uint256 CO2O) external {
      
        ERC721(NFTaddress).safeTransferFrom(msg.sender, address(this), Ext_NFT_ID);

        DepositInfo memory newDeposit;

            newDeposit.owner = msg.sender;
            newDeposit.Ext_NFT_Address = NFTaddress;
            newDeposit.Int_NFT_ID = _intIDcounter.current();
            newDeposit.Ext_NFT_ID = Ext_NFT_ID;
            newDeposit.depositTimestamp = block.timestamp;
            newDeposit.totalCO2O = CO2O;
            newDeposit.fractions = 0;
            newDeposit.fractionalized = false;
        
        NftIndex[NFTaddress][Ext_NFT_ID] = UserToDeposits[msg.sender].Deposit.length;

        _intIDcounter.increment();

        UserToDeposits[msg.sender].Deposit.push(newDeposit);

    }

    function getDepositInfo(address _Account, address _Ext_NFT_Address, uint256 _Ext_NFT_ID) external view returns (address, address, uint256, uint256, uint256, uint256, bool, uint256) {
 
        uint256 _NFTindex = NftIndex[_Ext_NFT_Address][_Ext_NFT_ID]; // Look up the deposit information using the NftIndex mapping

        DepositInfo storage deposit = UserToDeposits[_Account].Deposit[_NFTindex]; // Get the deposit information using the UserToDeposits mapping and the deposit index

        return (deposit.owner, deposit.Ext_NFT_Address, deposit.Ext_NFT_ID, deposit.Int_NFT_ID, deposit.depositTimestamp, deposit.totalCO2O, deposit.fractionalized, deposit.fractions); // Return the relevant information from the deposit
    }

    function WithdrawNFT(uint256 _Int_NFT_ID) external fractionalized0(_Int_NFT_ID) NFTowner(_Int_NFT_ID) {
        
        address _NFTaddress = UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].Ext_NFT_Address;
        uint256 _nftID =  UserToDeposits[msg.sender].Deposit[_Int_NFT_ID].Ext_NFT_ID;

        delete UserToDeposits[msg.sender].Deposit[_Int_NFT_ID];

        ERC721(_NFTaddress).safeTransferFrom(address(this), msg.sender, _nftID);
    }

    function FractionalizeNFT(uint256 fractions, uint256 _Int_NFT_ID) external fractionalized1(_Int_NFT_ID) NFTowner(_Int_NFT_ID) {
       
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

    //Required override by solidity for safely receiving ERC721 tokens
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns(bytes4) {
        return this.onERC721Received.selector;
    } 
}
