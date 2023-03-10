// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//Imports
    //Making use of as much battle-tested code imports as possible to minimize bugs and possible attack vectors
    import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
    import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
    import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
    import "@openzeppelin/contracts/security/Pausable.sol";
    import "@openzeppelin/contracts/access/AccessControl.sol";
    import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
    import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
    import "@openzeppelin/contracts/utils/Counters.sol";
    import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ECO_DAO is ERC1155, ERC1155Holder, IERC721Receiver, Pausable, AccessControl, ERC1155Supply {

//Library initialization
    using Counters for Counters.Counter;
    using SafeMath for uint256;

//Declarations
    //Global counters
        Counters.Counter private _Counter1;
        Counters.Counter private _Counter2;

    //ERC1155 Tokens
        uint256 public constant ECO = 0;                                                               
        uint256 public constant CO2O = 1;

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

        mapping(address => DepositStorage) User2Deposits;
        mapping(address => mapping (uint256 => uint256)) NftIndex;  
    
    //For Governance

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
        uint256 fee = 10;

        uint256 private Reserve_CO2O = 0;
        uint256 private Reserve_WEI = 0;
        uint256 private Reserve_Interest = 0;

        uint256 public buyRate;
        uint256 public sellRate;

        mapping(address => uint256) User2DividendLog;

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
        _mint(msg.sender, 0, 500 , "");
        _mint(msg.sender, 1, 500 , "");
    }


//Functionalities
    //Security admin bypass functionalities
        function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
            _pause();
        }

        function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
            _unpause();
        }

    //Function for AMM test purposes
        function fundAMM(uint256 _amountCO2O) external payable onlyRole(DEFAULT_ADMIN_ROLE) {
            
            Reserve_WEI = Reserve_WEI.add(msg.value);

            _safeTransferFrom(msg.sender, address(this), CO2O, _amountCO2O, "");          
            Reserve_CO2O = Reserve_CO2O.add(_amountCO2O);

            _updateRates();
        }

    //ECO Governance funcionalities
        function addCertProposal(uint256 _Nftindex) external whenNotPaused returns(uint256 Proposal_ID) {
            
            ProposalInfo memory newProposal = ProposalInfo(_Nftindex, msg.sender, block.timestamp, 0);

            uint256 ProposalID = _Counter2.current();
            
            Index2Proposal[ProposalID] = newProposal;

            _Counter2.increment();

            return ProposalID; 
        }

        function vote(uint256 _proposalID) external whenNotPaused {
            require(!Voter2Proposal[msg.sender][_proposalID].hasVoted && balanceOf(msg.sender, ECO) >  0, "Already voted / No ECO tokens to vote");

            VoteInfo memory newVoter = VoteInfo(true, balanceOf(msg.sender, ECO));

            Index2Proposal[_proposalID].voteCount = Index2Proposal[_proposalID].voteCount.add(newVoter.votes);
            
            Voter2Proposal[msg.sender][_proposalID] = newVoter;
        }

        function approveCert(uint256 _proposalID) external whenNotPaused {
            require(Index2Proposal[_proposalID].voteCount > totalSupply(ECO).div(2), "Not enough votes");

            uint256 _NFT_ID = Index2Proposal[_proposalID].Nftindex;
            User2Deposits[msg.sender].Deposit[_NFT_ID].approved = true;
        }

        function collectInterest() external {
            require(User2DividendLog[msg.sender].sub(block.timestamp) > 216000 /*1 month */);
            
            uint256 _share = balanceOf(msg.sender, ECO).div(totalSupply(ECO));
            uint256 _dividend = (Reserve_Interest).mul(_share);
            Reserve_Interest = Reserve_Interest.sub(_dividend);

            User2DividendLog[msg.sender] = block.timestamp;

            payable(msg.sender).transfer(_dividend);
        }


    //Fractionalization functionalitities
        function DepositCert(address _Ext_NFT_Address, uint256 _Ext_NFT_ID, uint256 _totalCO2O) external whenNotPaused {
        
            ERC721(_Ext_NFT_Address).safeTransferFrom(msg.sender, address(this), _Ext_NFT_ID);

            DepositInfo memory newDeposit = DepositInfo(msg.sender, _Ext_NFT_Address, _Ext_NFT_ID, block.timestamp, _totalCO2O, false, false);
        
            NftIndex[_Ext_NFT_Address][_Ext_NFT_ID] = _Counter1.current();

            _Counter1.increment();

            User2Deposits[msg.sender].Deposit.push(newDeposit);
        }

        function getCertInfo(address _Account, address _Ext_NFT_Address, uint256 _Ext_NFT_ID) external view returns (address, address, uint256, uint256, uint256, uint256, bool, bool) {
    
            uint256 _NFTindex = NftIndex[_Ext_NFT_Address][_Ext_NFT_ID]; 

            DepositInfo storage deposit = User2Deposits[_Account].Deposit[_NFTindex]; 

            return (deposit.owner, deposit.Ext_NFT_Address, deposit.Ext_NFT_ID, _NFTindex, deposit.depositTimestamp, deposit.totalCO2O, deposit.approved, deposit.fractionalized); 
        }

        function WithdrawCert(uint256 _NFTindex) external whenNotPaused {
            require(User2Deposits[msg.sender].Deposit[_NFTindex].owner == msg.sender);
            require(User2Deposits[msg.sender].Deposit[_NFTindex].fractionalized == false);

            delete User2Deposits[msg.sender].Deposit[_NFTindex];

            uint256 _nftID = User2Deposits[msg.sender].Deposit[_NFTindex].Ext_NFT_ID;
            address _Ext_NFT_Address = User2Deposits[msg.sender].Deposit[_NFTindex].Ext_NFT_Address;
            ERC721(_Ext_NFT_Address).safeTransferFrom(address(this), msg.sender, _nftID);
        }

        function FractionalizeCert(uint256 _NFTindex) external whenNotPaused {
            require(User2Deposits[msg.sender].Deposit[_NFTindex].owner == msg.sender);
            require(User2Deposits[msg.sender].Deposit[_NFTindex].fractionalized == false);

            User2Deposits[msg.sender].Deposit[_NFTindex].fractionalized = true;

            _mint(address(msg.sender), CO2O, User2Deposits[msg.sender].Deposit[_NFTindex].totalCO2O, "");
        }

        function UnifyFractions(uint256 _NFTindex) external whenNotPaused {
            require(User2Deposits[msg.sender].Deposit[_NFTindex].owner == msg.sender);
            require(User2Deposits[msg.sender].Deposit[_NFTindex].fractionalized == false);
            uint256 totalFractions = User2Deposits[msg.sender].Deposit[_NFTindex].totalCO2O;
            require(balanceOf(msg.sender, CO2O) > totalFractions);
            
            _burn(address(msg.sender), CO2O, totalFractions);

            User2Deposits[msg.sender].Deposit[_NFTindex].fractionalized = false;
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
            uint256 requiredValue = _amountCO2O.mul(buyRate).add(_amountCO2O.mul(buyRate).mul(fee).div(100));  
            require(msg.value >=  requiredValue, "Not enough WEI");

            Reserve_WEI = Reserve_WEI.add(msg.value.sub(msg.value.mul(fee.div(100))));
            Reserve_Interest = Reserve_Interest.add(msg.value.mul(fee.div(100)));

            uint256 excessValue = msg.value.sub(requiredValue);
            (excessValue > 0) ? payable(msg.sender).transfer(excessValue) : ();

            Reserve_CO2O = Reserve_CO2O.sub(_amountCO2O);
            _safeTransferFrom(address(this), msg.sender, CO2O, _amountCO2O, "");

            _updateRates();
        }

        function sellCO2O(uint256 _amountCO2O) external whenNotPaused {

            _safeTransferFrom(msg.sender, address(this), CO2O, _amountCO2O, "");
            Reserve_CO2O = Reserve_CO2O.add(_amountCO2O);

            Reserve_WEI = Reserve_WEI.sub(_amountCO2O.mul(sellRate));
            payable(msg.sender).transfer(_amountCO2O.mul(sellRate));

            _updateRates();
        }

    //Offsetting functionalities
        function GoGreen(uint256 _amountCO2O, string calldata purpose) external whenNotPaused {

            _burn(msg.sender, CO2O, _amountCO2O);

            OffsetInfo memory newOffset = OffsetInfo(_amountCO2O, keccak256(abi.encodePacked(_amountCO2O, purpose)));

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
    //Required override by solidity to signal support of standard interfaces
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, ERC1155Receiver, AccessControl) returns (bool) { 
        return super.supportsInterface(interfaceId);
    }
}