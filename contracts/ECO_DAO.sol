// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//Imports
    //Making use of as much battle-tested code imports as possible to minimize bugs and possible attack vectors
    import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
    import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
    import "@openzeppelin/contracts/security/Pausable.sol";
    import "@openzeppelin/contracts/access/AccessControl.sol";
    import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
    import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
    import "@openzeppelin/contracts/utils/Counters.sol";
    import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ECO_DAO is ERC1155, IERC721Receiver, Pausable, AccessControl, ERC1155Supply {

//Library initialization
    using Counters for Counters.Counter; //using Counters library to safely increment global counters
    using SafeMath for uint256; //using SafeMath library to avoid integer overflow-/underflow attacks

//Declarations
    //Global counters
    Counters.Counter private _Counter1;
    Counters.Counter private _Counter2;
    
    //ERC1155 Tokens
    uint256 public constant ECO = 0;                                                               
    uint256 public constant CO2O = 1;
    uint256 public constant Reserve_CO2O = 2;
    uint256 public constant Reserve_WEI = 3;

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
        uint256 Nftindex;
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

    //For CFMM
    uint256 fee;

    uint256 buyRate;
    uint256 sellRate;

    mapping(address => uint256) User2LPshares;

    //For Offset Registry
    struct OffsetStorage {
        OffsetInfo[] Offsets;
    }

    struct OffsetInfo {
        uint256 Offset_Amount;
        bytes32 Proof_of_OffSet;
    }

    mapping(address => OffsetStorage) User2OffSet;


//Constructor
    constructor() ERC1155 ("") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

//Modifiers


//Functionalities
    //Security admin bypass functionalities
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    //ECO Governance funcionalities
    function addProposal(uint256 _Nftindex) external whenNotPaused {
        ProposalInfo memory newProposal;

            newProposal.Nftindex = _Nftindex;
            newProposal.proposer = msg.sender;
            newProposal.proposalTimestamp = block.timestamp;
            newProposal.voteCount = 0;
        
        Index2Proposal[_Counter2.current()] = newProposal;

        _Counter2.increment();

        Proposals.push(newProposal);         
    }

    function vote(uint256 _proposalID) external whenNotPaused {
        VoteInfo memory newVoter;
            newVoter.hasVoted = true;
            newVoter.votes = balanceOf(msg.sender, ECO);

        Index2Proposal[_proposalID].voteCount.add(newVoter.votes);
        
        Voter2Proposal[msg.sender][_proposalID] = newVoter;
    }

    function approveCO2O(uint256 _proposalID) external whenNotPaused {
        uint256 _NFT_ID = Index2Proposal[_proposalID].Nftindex;

        UserToDeposits[msg.sender].Deposit[_NFT_ID].approved = true;
    }

    //Fractionalization functionalitities
    function DepositNFT(address _Ext_NFT_Address, uint256 _Ext_NFT_ID, uint256 _totalCO2O) external whenNotPaused {
      
        ERC721(_Ext_NFT_Address).safeTransferFrom(msg.sender, address(this), _Ext_NFT_ID);

        DepositInfo memory newDeposit;

            newDeposit.owner = msg.sender;
            newDeposit.Ext_NFT_Address = _Ext_NFT_Address;
            newDeposit.Ext_NFT_ID = _Ext_NFT_ID;
            newDeposit.depositTimestamp = block.timestamp;
            newDeposit.totalCO2O = _totalCO2O;
            newDeposit.approved = false;
            newDeposit.fractionalized = false;
        
        NftIndex[_Ext_NFT_Address][_Ext_NFT_ID] = _Counter1.current();

        _Counter1.increment();

        UserToDeposits[msg.sender].Deposit.push(newDeposit);
    }

    function getDepositInfo(address _Account, address _Ext_NFT_Address, uint256 _Ext_NFT_ID) external view returns (address, address, uint256, uint256, uint256, uint256, bool, bool) {
 
        uint256 _NFTindex = NftIndex[_Ext_NFT_Address][_Ext_NFT_ID]; 

        DepositInfo storage deposit = UserToDeposits[_Account].Deposit[_NFTindex]; 

        return (deposit.owner, deposit.Ext_NFT_Address, deposit.Ext_NFT_ID, _NFTindex, deposit.depositTimestamp, deposit.totalCO2O, deposit.approved, deposit.fractionalized); 
    }

    function WithdrawNFT(uint256 _NFTindex) external whenNotPaused {

        delete UserToDeposits[msg.sender].Deposit[_NFTindex];

        uint256 _nftID = UserToDeposits[msg.sender].Deposit[_NFTindex].Ext_NFT_ID;
        address _Ext_NFT_Address = UserToDeposits[msg.sender].Deposit[_NFTindex].Ext_NFT_Address;
        ERC721(_Ext_NFT_Address).safeTransferFrom(address(this), msg.sender, _nftID);
    }

    function FractionalizeNFT(uint256 _NFTindex) external whenNotPaused {
       
        UserToDeposits[msg.sender].Deposit[_NFTindex].fractionalized = true;

        _mint(address(msg.sender), CO2O, UserToDeposits[msg.sender].Deposit[_NFTindex].totalCO2O, "");
    }

    function UnifyFractions(uint256 _NFTindex) external whenNotPaused {
        
        uint256 totalFractions = UserToDeposits[msg.sender].Deposit[_NFTindex].totalCO2O;
        require(balanceOf(msg.sender, CO2O) == totalFractions, "Insufficient fractions");
        
        _burn(address(msg.sender), CO2O, totalFractions);

        UserToDeposits[msg.sender].Deposit[_NFTindex].fractionalized = false;
    }

    //CFMM functionalities
    function _updateRates() private {
        buyRate = Reserve_WEI.div(Reserve_CO2O);
        sellRate = Reserve_CO2O.div(Reserve_WEI);
    }
    
    function _buyRate() private view returns(uint256) {
        return buyRate;
    }

    function _sellRate() private view returns(uint256) {
        return sellRate;
    }

    function buyCO2O(uint256 _amountCO2O) external payable whenNotPaused {
        require(msg.value >= _amountCO2O.mul(buyRate).add(fee));
        Reserve_CO2O.sub(_amountCO2O);
        Reserve_WEI.add(msg.value);
        _safeTransferFrom(address(this), msg.sender, CO2O, _amountCO2O, "");
        _updateRates();
    }

    function sellCO2O(uint256 _amountCO2O) external whenNotPaused {
        require(_amountCO2O >= _amountCO2O.mul(sellRate));
        Reserve_CO2O.add(_amountCO2O.mul(sellRate));
        Reserve_WEI.sub(_amountCO2O);
        _safeTransferFrom(msg.sender, address(this), CO2O, _amountCO2O, "");
        _updateRates();
    }

    //Offsetting functionalities
    function GoGreen(uint256 _amountCO2O, string calldata purpose) external whenNotPaused {

        _burn(msg.sender, CO2O, _amountCO2O);

        OffsetInfo memory newOffset;
            newOffset.Offset_Amount = _amountCO2O;
            newOffset.Proof_of_OffSet = keccak256(abi.encodePacked(_amountCO2O, purpose));
        User2OffSet[msg.sender].Offsets.push(newOffset);
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