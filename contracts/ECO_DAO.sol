// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//Making use of as much battle-tested code imports as possible to minimize bugs and possible attack vectors
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract ECO_DAO is ERC1155, IERC721Receiver, Pausable, AccessControl, ERC1155Supply {
    using Counters for Counters.Counter; //using Counters library to safely increment global counters
    using SafeMath for uint256; //using SafeMath library to avoid integer overflow-/underflow attacks

//Declarations
    Counters.Counter private _Counter1;
    Counters.Counter private _Counter2;

    //For Roles
    bytes32 public constant ECO_Gov = keccak256("ECO_Gov");

    //For Fractionalizer
    struct DepositStorage {
        DepositInfo[] Deposit;
    }

    struct DepositInfo {
        address owner;
        address Ext_NFT_Address;
        uint256 Ext_NFT_ID;
        uint256 depositTimestamp;
        uint256 totalCO2O;
        bool approved;
        bool fractionalized;
    }

    mapping(address => DepositStorage) UserToDeposits;
    mapping(address => mapping (uint256 => uint256)) NftIndex;  
    
    //For Governance


    ProposalInfo[] public Proposals;

    struct ProposalInfo {
        bytes name;
        address proposer;
        uint256 proposalTimestamp;
        uint256 voteCount;
    }

    struct VoteInfo {
        bool hasVoted;
        uint256 votes;  
    }

    mapping(uint256 => ProposalInfo) public Index2Proposal;
    mapping(address => mapping(uint256 => VoteInfo)) public Voter2Proposal;

//Constructor
    constructor() ERC1155 ("") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ECO_Gov, msg.sender);
    }

//Modifiers
    //Fractionalization Checkers
    modifier fractionalized0(uint256 _NFTindex) {
        require(UserToDeposits[msg.sender].Deposit[_NFTindex].fractionalized == false, "Token has already been fractionalized");
        _;
    }   

    modifier fractionalized1(uint256 _NFTindex) {
        require(UserToDeposits[msg.sender].Deposit[_NFTindex].fractionalized == true, "Token has not yet been fractionalized");
        _;
    }  

    modifier validAmountFraction(uint256 _amountFraction) {
        require(balanceOf(msg.sender, 1) >= _amountFraction, "Insufficient fractions");
        require(_amountFraction >= 0, "Ammount cannot be Zero");
        _;
    }

    modifier NFTowner(uint256 _NFTindex) {
        require(UserToDeposits[msg.sender].Deposit[_NFTindex].owner == msg.sender, "Only the owner of this NFT can access it");
        _;
    }

    modifier onlyApproved (uint256 _NFTindex) {
        require(UserToDeposits[msg.sender].Deposit[_NFTindex].approved == true, "Not approved by Governance. Please submit approval request");
        _;
    }

    //Voting Checkers
    modifier GovTokens() {
        require(balanceOf(msg.sender, 0) >=  0, "No voting power. Get ECO tokens to vote");
        _;
    }
    
    modifier noDoubleVote(uint256 _proposalID) {
        require(!Voter2Proposal[msg.sender][_proposalID].hasVoted, "You have already voted for this proposal.");
        _;
    }

    modifier canVerify(uint256 _proposalID) {
        require(Index2Proposal[_proposalID].voteCount > totalSupply(1).div(2), "Not enough votes");
        _;
    }

//Functionalities
    //Security admin bypass functionalities
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    //ECO Governance funcionalities
    function addProposal(bytes calldata _Proposal_Name) external {
        ProposalInfo memory newProposal;

            newProposal.name = _Proposal_Name;
            newProposal.proposer = msg.sender;
            newProposal.proposalTimestamp = block.timestamp;
            newProposal.voteCount = 0;
        
        Index2Proposal[_Counter2.current()] = newProposal;

        _Counter2.increment();

        Proposals.push(newProposal);         
    }

    function vote(uint256 _proposalID) external GovTokens noDoubleVote(_proposalID) {
        VoteInfo memory newVoter;
            newVoter.hasVoted = true;
            newVoter.votes = balanceOf(msg.sender, 0);

        Index2Proposal[_proposalID].voteCount.add(newVoter.votes);
        
        Voter2Proposal[msg.sender][_proposalID] = newVoter;
    }

    function verify(uint256 _proposalID) external canVerify {
        
    }


    //Fractionalization functionalitities
    function DepositNFT(address _Ext_NFT_Address, uint256 _Ext_NFT_ID, uint256 _CO2O) external {
      
        ERC721(_Ext_NFT_Address).safeTransferFrom(msg.sender, address(this), _Ext_NFT_ID);

        DepositInfo memory newDeposit;

            newDeposit.owner = msg.sender;
            newDeposit.Ext_NFT_Address = _Ext_NFT_Address;
            newDeposit.Ext_NFT_ID = _Ext_NFT_ID;
            newDeposit.depositTimestamp = block.timestamp;
            newDeposit.totalCO2O = _CO2O;
            newDeposit.approved = false;
            newDeposit.fractionalized = false;
        
        NftIndex[_Ext_NFT_Address][_Ext_NFT_ID] = _Counter1.current();

        _Counter1.increment();

        UserToDeposits[msg.sender].Deposit.push(newDeposit);
    }

    function getDepositInfo(address _Account, address _Ext_NFT_Address, uint256 _Ext_NFT_ID) external view returns (address, address, uint256, uint256, uint256, uint256, bool, bool) {
 
        uint256 _NFTindex = NftIndex[_Ext_NFT_Address][_Ext_NFT_ID]; // Look up the deposit information using the NftIndex mapping

        DepositInfo storage deposit = UserToDeposits[_Account].Deposit[_NFTindex]; // Get the deposit information using the UserToDeposits mapping and the deposit index

        return (deposit.owner, deposit.Ext_NFT_Address, deposit.Ext_NFT_ID, _NFTindex, deposit.depositTimestamp, deposit.totalCO2O, deposit.approved, deposit.fractionalized); // Return the relevant information from the deposit
    }

    function WithdrawNFT(uint256 _NFTindex) external fractionalized0(_NFTindex) NFTowner(_NFTindex) {

        delete UserToDeposits[msg.sender].Deposit[_NFTindex];

        uint256 _nftID = UserToDeposits[msg.sender].Deposit[_NFTindex].Ext_NFT_ID;
        address _Ext_NFT_Address = UserToDeposits[msg.sender].Deposit[_NFTindex].Ext_NFT_Address;
        ERC721(_Ext_NFT_Address).safeTransferFrom(address(this), msg.sender, _nftID);
    }

    function FractionalizeNFT(uint256 _NFTindex) external fractionalized0(_NFTindex) NFTowner(_NFTindex) onlyApproved(_NFTindex) {
       
        UserToDeposits[msg.sender].Deposit[_NFTindex].fractionalized = true;

        _mint(address(msg.sender), 1, UserToDeposits[msg.sender].Deposit[_NFTindex].totalCO2O, "");
    }

    function UnifyFractions(uint256 _NFTindex) external fractionalized0(_NFTindex) NFTowner(_NFTindex) {
        
        uint256 totalFractions = UserToDeposits[msg.sender].Deposit[_NFTindex].totalCO2O;
        require(balanceOf(msg.sender, 1) == totalFractions, "Insufficient fractions");
        
        _burn(address(msg.sender), 1, totalFractions);

        UserToDeposits[msg.sender].Deposit[_NFTindex].fractionalized = false;
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
    //Required override by solidity to signal support of AccessControl Interface
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) { 
        return super.supportsInterface(interfaceId);
    }
}
