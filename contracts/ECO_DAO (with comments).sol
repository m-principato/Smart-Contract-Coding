// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//Imports
    //Making use of as much battle-tested code imports as possible to minimize bugs and possible attack vectors
    
    import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";                     //Needed for the main structure of our code
    import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";         //Needed for handling deposits in the AMM
    import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";              //Needed for handling the fractionalization of NFTs
    import "@openzeppelin/contracts/security/Pausable.sol";                         //Needed for emergency functionalities
    import "@openzeppelin/contracts/access/AccessControl.sol";                      //Needed for setting hierarchy structures with different permissions
    import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";    //Needed for reading the total supply of a ERC1155 token
    import "@openzeppelin/contracts/token/ERC721/ERC721.sol";                       //Needed for accessing the functionalities of the NFT
    
    import "@openzeppelin/contracts/utils/Counters.sol";                            //Needed for incrementing counters
    import "@openzeppelin/contracts/utils/math/SafeMath.sol";                       //Needed for arithmetic operations

contract ECO_DAO is ERC1155, ERC1155Holder, IERC721Receiver, Pausable, AccessControl, ERC1155Supply {

//Library initialization
    using Counters for Counters.Counter; //using the counters library for the counter struct
    using SafeMath for uint256;          //using the SafeMath library for the uint data type

//Declarations
    //Declaring two global counter structs
        Counters.Counter private _Counter1;
        Counters.Counter private _Counter2;

    //Declaring two ERC1155 Tokens (CO2O Utility Token + ECO Governance Token)
        uint256 public constant ECO = 0;                                                               
        uint256 public constant CO2O = 1;

    //For Fractionalizer
        struct DepositStorage {         //Wrapping an array of strcucts in a struct because solidity does not allow a mapping to an array (see User2Deposits)
            DepositInfo[] Deposit;      
        }

        struct DepositInfo {           //The structs in the array are of the type, which is defined here. It is used to represent an external deposited Carbon Offset Certificate NFT
            address owner;
            address Ext_NFT_Address;
            uint256 Ext_NFT_ID;
            uint256 depositTimestamp;
            uint256 totalCO2O;
            bool approved;
            bool fractionalized;
        }

        mapping(address => DepositStorage) User2Deposits;           //This mapping maps a user to the information of his deposited NFTs (each Deposit is an individual entry in the Deposit array)
        mapping(address => mapping (uint256 => uint256)) NftIndex;  //This mapping maps an external NFT SC address to its NFT external IDs and gives them a unique internal ID
    
    //For Governance

        struct ProposalInfo {           //This struct encompasses information that is needed for the proposal
            uint256 Nftindex;
            address proposer;
            uint256 proposalTimestamp;
            uint256 voteCount;
        }

        struct VoteInfo {              //This struct encompasses information that is needed for keeping track of the voting process
            bool hasVoted;
            uint256 votes;  
        }

        mapping(uint256 => ProposalInfo) public Index2Proposal;                     //This mapping maps an Index of a proposal to its proposal info
        mapping(address => mapping(uint256 => VoteInfo)) public Voter2Proposal;     //This mapping maps a user to a proposal index and the associated vote infromation on the proposal

    //For CFMM
        uint256 fee = 10;                               //Hardcoded value of 10% without use of precision -> Room for improvement: (1) Setter function, (2) Usage of precision for decimals 

        uint256 private Reserve_CO2O = 0;               //This keeps track of the total CO2O in the AMM
        uint256 private Reserve_WEI = 0;                //Same for WEI
        uint256 private Reserve_Interest = 0;           //Same for the trading fee

        uint256 public buyRate;                         //buyRate for the AMM pricing
        uint256 public sellRate;                        //sellRate for the AMM pricing (inverse of the buyRate)

        mapping(address => uint256) User2DividendLog;   //This mapping maps a user to a timestamp which later becomes important to prevent abuse of dividend payout

    //For Offset Registry
        struct OffsetStorage {                          //Struct wrapper around an array that functions as BURN Registry and saves all offset activities 
            OffsetInfo[] Offsets;
        }

        struct OffsetInfo {                             //Struct type that is pushed into the array
            uint256 Offset_Amount;                              
            bytes32 Proof_of_OffSet;
        }

        mapping(address => OffsetStorage) User2OffSet;  //Mapping that maps a user to his offset history


//Constructor
    constructor() ERC1155 ("") {                           //Initial definition of roles and minting of the tokens for test pruposes
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _mint(msg.sender, 0, 500 , "");
        _mint(msg.sender, 1, 500 , "");
    }


//Functionalities
    //Security admin bypass functionalities
        function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {          //Via "whenNotPaused" function modifiers, an adming can pause contract
            _pause();
        }

        function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {        //...and unpause it
            _unpause();
        }

    //Function for AMM test purposes
        function fundAMM(uint256 _amountCO2O) external payable onlyRole(DEFAULT_ADMIN_ROLE) {       //This is a test function, however, it might be necessary to fund the market at the beginning of the DAO once to kickstart the AMM
            
            Reserve_WEI = Reserve_WEI.add(msg.value);

            _safeTransferFrom(msg.sender, address(this), CO2O, _amountCO2O, "");          
            Reserve_CO2O = Reserve_CO2O.add(_amountCO2O);

            _updateRates();
        }

    //ECO Governance funcionalities
        function addCertProposal(uint256 _Nftindex) external whenNotPaused returns(uint256 Proposal_ID) {   //Function to add a new proposal for the fractionalization of a CO2O Certificate
            
            ProposalInfo memory newProposal = ProposalInfo(_Nftindex, msg.sender, block.timestamp, 0);      //This sets all the proposal information

            uint256 ProposalID = _Counter2.current();                                                       //This gives each proposal a unique internal ID
            
            Index2Proposal[ProposalID] = newProposal;                                                       //Here the proposal is added to the mapping

            _Counter2.increment();                                                                           

            return ProposalID;                                                                              
        }

        function vote(uint256 _proposalID) external whenNotPaused {                                                                                     //Vote function
            require(!Voter2Proposal[msg.sender][_proposalID].hasVoted && balanceOf(msg.sender, ECO) >  0, "Already voted / No ECO tokens to vote");     //Only one vote per address and only gov token holders can vote

            VoteInfo memory newVoter = VoteInfo(true, balanceOf(msg.sender, ECO));                                                                      //Here the vote information is created -> each gov holder votes with the whole weight of his ECO ownings

            Index2Proposal[_proposalID].voteCount = Index2Proposal[_proposalID].voteCount.add(newVoter.votes);                                          //The vote count of the proposal is increased by the ECO weight of the owner
            
            Voter2Proposal[msg.sender][_proposalID] = newVoter;                                                                                         //Here the vote information is added to the nested mapping of the proposals that a user has voted on
        }

        function approveCert(uint256 _proposalID) external whenNotPaused {                                      //Approval function
            require(Index2Proposal[_proposalID].voteCount > totalSupply(ECO).div(2), "Not enough votes");       //Can only be casted if the proposal has majority votes 

            uint256 _NFT_ID = Index2Proposal[_proposalID].Nftindex;
            User2Deposits[msg.sender].Deposit[_NFT_ID].approved = true;                                         //Sets the approved value of the carbon certificate to true, so it then can be fractionalized later (i.e., passes the checker)
        }

        function collectInterest() external {                       
            require(User2DividendLog[msg.sender].sub(block.timestamp) > 216000 /*1 month */);                   //Checker to prevent abuse of the dividend payout system. Only each month dividends can be payed out
            
            uint256 _share = balanceOf(msg.sender, ECO).div(totalSupply(ECO));                                  //Calculate the share of the ECO that an owner has of the total ECO Supply
            uint256 _dividend = (Reserve_Interest).mul(_share);                                                 //Use this share to calculate the partition that an ECO owner can claim of the interest pool (i.e., his dividend)
            Reserve_Interest = Reserve_Interest.sub(_dividend);                                                 //Subtract this dividend from the pool

            User2DividendLog[msg.sender] = block.timestamp;                                                     //Set a new timestamp for the last claim (for the checker)

            payable(msg.sender).transfer(_dividend);                                                            //Pay out the dividend
        }


    //Fractionalization functionalitities
        function DepositCert(address _Ext_NFT_Address, uint256 _Ext_NFT_ID, uint256 _totalCO2O) external whenNotPaused {                            //This function takes an NFT as deposit
        
            ERC721(_Ext_NFT_Address).safeTransferFrom(msg.sender, address(this), _Ext_NFT_ID);                                                      //Therefore this command calls the external NFT contract and transfers the NFT to this contract (must be approved before)

            DepositInfo memory newDeposit = DepositInfo(msg.sender, _Ext_NFT_Address, _Ext_NFT_ID, block.timestamp, _totalCO2O, false, false);      //Here, the information of the deposit is created -> internal representation of an external NFT
        
            NftIndex[_Ext_NFT_Address][_Ext_NFT_ID] = _Counter1.current();                                                                          //The internal representation gets a unique internal ID

            _Counter1.increment();

            User2Deposits[msg.sender].Deposit.push(newDeposit);                                                                                     //The new internal NFT is pushed into the array which is inside the User2Deposits mapping
        }

        function getCertInfo(address _Account, address _Ext_NFT_Address, uint256 _Ext_NFT_ID) external view returns (address, address, uint256, uint256, uint256, uint256, bool, bool) { //this is just a getter function that returns all relevant deposit infos
    
            uint256 _NFTindex = NftIndex[_Ext_NFT_Address][_Ext_NFT_ID]; 

            DepositInfo storage deposit = User2Deposits[_Account].Deposit[_NFTindex]; 

            return (deposit.owner, deposit.Ext_NFT_Address, deposit.Ext_NFT_ID, _NFTindex, deposit.depositTimestamp, deposit.totalCO2O, deposit.approved, deposit.fractionalized); 
        }

        function WithdrawCert(uint256 _NFTindex) external whenNotPaused {                               //This function can be used to withdraw a deposited NFT
            require(User2Deposits[msg.sender].Deposit[_NFTindex].owner == msg.sender);                  //But only if the owner of the Deposit calls it
            require(User2Deposits[msg.sender].Deposit[_NFTindex].fractionalized == false);              //And only if it hasnt been fractionalized yet

            delete User2Deposits[msg.sender].Deposit[_NFTindex];                                        //Then the deposit (i.e., internal NFT representation) is deleted

            uint256 _nftID = User2Deposits[msg.sender].Deposit[_NFTindex].Ext_NFT_ID;                   
            address _Ext_NFT_Address = User2Deposits[msg.sender].Deposit[_NFTindex].Ext_NFT_Address;
            ERC721(_Ext_NFT_Address).safeTransferFrom(address(this), msg.sender, _nftID);               //And we call the external NFT contract to transfer the ownership of the NFT back to the user
        }

        function FractionalizeCert(uint256 _NFTindex) external whenNotPaused {                              //This function fractionalizes a deposited NFT with the same checkers as above
            require(User2Deposits[msg.sender].Deposit[_NFTindex].owner == msg.sender);                      
            require(User2Deposits[msg.sender].Deposit[_NFTindex].fractionalized == false);                  

            User2Deposits[msg.sender].Deposit[_NFTindex].fractionalized = true;                             //Fractonalized property gets set to true

            _mint(address(msg.sender), CO2O, User2Deposits[msg.sender].Deposit[_NFTindex].totalCO2O, "");   //The amount of CO2O claimed in the Certificate NFT gets minted (i.e., the certificate gets fractionalized into the amount of tokens so that each token is worth 1 CO2O unit)
        }

        function UnifyFractions(uint256 _NFTindex) external whenNotPaused {                                 //If a depositor has enough CO2O he can unify (i.e., un-fractionalize) a previous fractionalized Certificate (and then withdraw it again)
            require(User2Deposits[msg.sender].Deposit[_NFTindex].owner == msg.sender);
            require(User2Deposits[msg.sender].Deposit[_NFTindex].fractionalized == false);
            uint256 totalFractions = User2Deposits[msg.sender].Deposit[_NFTindex].totalCO2O;    
            require(balanceOf(msg.sender, CO2O) > totalFractions);
            
            _burn(address(msg.sender), CO2O, totalFractions);                                              //The minted fractions get burned again

            User2Deposits[msg.sender].Deposit[_NFTindex].fractionalized = false;                           //And the fractionalized property is set to false again
        }

    //CFMM functionalities
        function _updateRates() private {                   //This function updates exchange rates (calculation as seen below)
            buyRate = Reserve_WEI.div(Reserve_CO2O);
            sellRate = Reserve_CO2O.div(Reserve_WEI);
        }
        
        function _buyRate() private view returns(uint256) {
            return buyRate;
        }

        function _sellRate() private view returns(uint256) {
            return sellRate;
        }

        function buyCO2O(uint256 _amountCO2O) external payable whenNotPaused {                                  //This function enabled to buy CO2O with WEI via a pricing rule
            uint256 requiredValue = _amountCO2O.mul(buyRate).add(_amountCO2O.mul(buyRate).mul(fee).div(100));             
            require(msg.value >=  requiredValue, "Not enough WEI");                                             //Checker that the user has enough tokens (price + fee), calculation as seen above

            Reserve_WEI = Reserve_WEI.add(msg.value.sub(msg.value.mul(fee.div(100))));                          //Adds only the price to the Wei Reserve (total - fee))
            Reserve_Interest = Reserve_Interest.add(msg.value.mul(fee.div(100)));                               //Adds only the fee to the Interest Reserve

            uint256 excessValue = msg.value.sub(requiredValue);                                 
            (excessValue > 0) ? payable(msg.sender).transfer(excessValue) : ();                                 //Fancy way to express an if statement: if excess value > 0 -> pay the excess value back, else -> do nothing and continue function

            Reserve_CO2O = Reserve_CO2O.sub(_amountCO2O);                                                       //Subtract the bought CO2O amount from the market reserve
            _safeTransferFrom(address(this), msg.sender, CO2O, _amountCO2O, "");                                //And transfer it to the buyer

            _updateRates();                                                                                     //Update exchange rates based on the new reserve state
        }

        function sellCO2O(uint256 _amountCO2O) external whenNotPaused {                                         //Function for selling CO2O for Wei

            _safeTransferFrom(msg.sender, address(this), CO2O, _amountCO2O, "");                                //Transfers CO2O from seller to reserve
            Reserve_CO2O = Reserve_CO2O.add(_amountCO2O);                                                       //Updates CO2O Reserve

            Reserve_WEI = Reserve_WEI.sub(_amountCO2O.mul(sellRate));                                           //Updates Wei Reserve
            payable(msg.sender).transfer(_amountCO2O.mul(sellRate));                                            //Pays seller with Wei

            _updateRates();                                                                                     //Update exchange rates based on the new reserve state
        }

    //Offsetting functionalities
        function GoGreen(uint256 _amountCO2O, string calldata purpose) external whenNotPaused {                             //Function that allows for verifiably burning carbon offsets (standard ERC1155 burn function has therefore been disabled)

            _burn(msg.sender, CO2O, _amountCO2O);                                                                           //Burns the tokens

            OffsetInfo memory newOffset = OffsetInfo(_amountCO2O, keccak256(abi.encodePacked(_amountCO2O, purpose)));       //Creates a new "Proof-of-Offset" entry with the public amount and a hash of amount and purpose

            User2OffSet[msg.sender].Offsets.push(newOffset);                                                                //Adds the proof to the public User2Offset mapping so that it can be verified
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