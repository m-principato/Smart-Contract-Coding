# ECO.DAO
-Coding Project for the module "Introduction to Blockchain Technology"-

## Security
We follow the established *ERC-1155 token standard*. We do **not** override functionalities besides overrides that are required by Solidity for improved interoperability (e.g., interface improvements). 

For security reasons, we further make use of the code from the [OpenZeppelin repository](https://github.com/OpenZeppelin/), which contains tested and constantly updated smart contract standards. Additionally, we make use of OpenZeppelin Libraries for increased security when adding custom functionalities which require computations and counters.

Specifically, we make use of
### Imported Contracts
- [ERC1155](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol)
- [ERC1155Supply](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/extensions/ERC1155Supply.sol)
- [ERC1155Burnable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/extensions/ERC1155Burnable.sol)
- [ERC721](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol)
- [IERC721Receiver](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol)
- [Pausable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/Pausable.sol)
- [AccessControl](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol)

### Imported Libraries
- [SafeMath](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol)
- [Counters](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol)

