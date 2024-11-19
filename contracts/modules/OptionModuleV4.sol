// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.12;

// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "../lib/ModuleBase.sol";
// import {IOwnable} from "../interfaces/internal/IOwnable.sol";
// import {Invoke} from "../lib/Invoke.sol";
// import {IOptionService} from "../interfaces/internal/IOptionService.sol";
// import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
// import {IOptionFacetV2} from "../interfaces/internal/IOptionFacetV2.sol";
// import {IOptionModuleV2} from "../interfaces/internal/IOptionModuleV2.sol";
// import {IPriceOracle} from "../interfaces/internal/IPriceOracle.sol";
// import {INFTFreeOptionPool} from "../interfaces/external/INFTFreeOptionPool.sol";

// contract OptionModuleV4 is ModuleBase, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
//     modifier onlyOwner() {
//         require( msg.sender == IOwnable(diamond).owner(),"OptionModule:only owner");  
//         _;
//     }
//     struct SignData{
//         bool lock;
//         uint256 total;
//         uint256 orderCount;
//     }
//     mapping(bytes=>SignData) public signData;

//     IOptionModuleV2 optionModuleV2;
//     /// @custom:oz-upgrades-unsafe-allow constructor
//     constructor() {
//         _disableInitializers();
//     }

//     function initialize(address _diamond,IOptionModuleV2 _optionModuleV2) public initializer {
//         __UUPSUpgradeable_init();
//         diamond = _diamond;
//         optionModuleV2 = _optionModuleV2;
//     }

//     function _authorizeUpgrade(
//         address newImplementation
//     ) internal override onlyOwner {}



// }