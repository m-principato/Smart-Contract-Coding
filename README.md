# ![Picture1](https://user-images.githubusercontent.com/118806662/214442399-69158fa2-2de6-4e6a-b68c-a68b265064bc.png)

## Background Information
ECO.DAO is a Coding Project for the module "Introduction to Blockchain Technology".

Please, see the [whitepaper](https://github.com/m-principato/Smart-Contract-Coding/blob/main/ECO_Whitepaper.pdf) and the [pitch deck](https://github.com/m-principato/Smart-Contract-Coding/blob/main/ICO_Pitch.pdf) for more information.

## Usage
The contract is ready to be deployed, however, it is very lengthy (see [Room for imporevements](https://github.com/m-principato/Smart-Contract-Coding#room-for-improvements)).

### Deploy with RemixIDE
Straightforward deployment via import of the [ECO.DAO sol contract](https://github.com/m-principato/Smart-Contract-Coding/blob/main/contracts/ECO_DAO.sol), compiling it, and deploying it.

### Deploy with Truffle
- **Initialize:** run `$ npm install -g truffle` and then `$ truffle init`
- **Compile:** run `$ npm install @openzeppelin/contracts` and then `$ truffle compile`
- **Deploy:** run `$ truffle develop` and then `truffle(develop)> deploy`  


## Security
We mainly follow the established **ERC-1155 token standard**. We do ***not*** override functionalities besides overrides that are required by Solidity for improved interoperability (e.g., interface improvements). 

For security reasons, we further make use of the code from the [OpenZeppelin repository](https://github.com/OpenZeppelin/), which contains tested and constantly updated smart contract standards. Additionally, we make use of OpenZeppelin Libraries for increased security when adding custom functionalities which require computations and counters.

Specifically, we make use of
### Imported Contracts
- [ERC1155](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol) 
- [ERC1155Supply](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/extensions/ERC1155Supply.sol) 
- [ERC1155Holder](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/utils/ERC1155Holder.sol) 
- [ERC721](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol) 
- [IERC721Receiver](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol) 
- [Pausable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/Pausable.sol) 
- [AccessControl](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol) 

### Imported Libraries
- [SafeMath](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol)
- [Counters](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol)

## Room for improvements
![work-in-progress]

The ECO.DAO contract is currently very long, almost exceeding the byte size limit of 24576 bytes that was proposed in [EIP-170](https://github.com/ethereum/EIPs/issues/170) and introduced by the [Spurious Dragon Ethereum Update](https://blog.ethereum.org/2016/11/18/hard-fork-no-4-spurious-dragon).

Removal of error strings enabled us to comply with the byte size limit. However, further steps need to be taken to reduce the contract size, for example by following common [guidlines for optimization](https://ethereum.org/en/developers/tutorials/downsizing-contracts-to-fight-the-contract-size-limit/).

