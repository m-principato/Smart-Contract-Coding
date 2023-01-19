// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//Needed for ERC721
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
//Needed for EC1155
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CarbonCert is ERC721, AccessControl {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("CarbonCert", "CCT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function safeMint(address to) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

contract Main is ERC1155, IERC721Receiver, Pausable, Ownable, ERC1155Burnable, ERC1155Supply {
    using SafeMath for uint256; //using SafeMath Library to avoid integer overflow-/underflow attacks

//Custom Fractionalizer declarations


    constructor() ERC1155("") { 
    //Placeholder//
    }

// Custom Modifiers:
    struct infoStorage {
            information[] info;
        }

        struct information {
            address owner;
            uint256 nftID;
            uint256 depositTimestamp;

            uint256 supply;

            bool fractionalized;
        }

        mapping(address => infoStorage) UserToDeposits;
        mapping(address => mapping (uint256 => uint256)) NftIndex;


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
    function fractionalize(uint256 nftID) public {
        ERC721 CarbonCert;
        CarbonCert.safeTransferFrom(msg.sender, address(this), nftID);

        information memory newDeposit;
            newDeposit.owner = msg.sender;
            newDeposit.nftID = nftID;
            newDeposit.depositTimestamp = block.timestamp;
            newDeposit.fractionalized = false;
        
        UserToDeposits[msg.sender].info.push(newDeposit);

    }

    //Required override by solidity
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns(bytes4) {
        return this.onERC721Received.selector;
    } 
}
