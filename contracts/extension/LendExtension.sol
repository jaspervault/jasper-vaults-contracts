// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "../lib/ModuleBase.sol";
// import {IOwnable} from "../interfaces/internal/IOwnable.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import {Invoke} from "../lib/Invoke.sol";
// import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
// import {IOptionExtension} from "../interfaces/internal/ILendExtension.sol";
// import {INonfungiblePositionManager} from "../interfaces/external/INonfungiblePositionManager.sol";

// contract OptionExtension is
//     ModuleBase,
//     IOptionExtension,
//     Initializable,
//     UUPSUpgradeable,
//     ReentrancyGuardUpgradeable
// {
//     using Invoke for IVault;
//     using SafeERC20 for IERC20;
//     modifier onlyOwner() {
//         require(
//             msg.sender == IOwnable(diamond).owner(),
//             "TradeModule:only owner"
//         );
//         _;
//     }

//     /// @custom:oz-upgrades-unsafe-allow constructor
//     constructor() {
//         _disableInitializers();
//     }

//     function initialize(address _diamond) public initializer {
//         __UUPSUpgradeable_init();
//         diamond = _diamond;
//     }

//     function _authorizeUpgrade(
//         address newImplementation
//     ) internal override onlyOwner {}

//     //-------replacementLiquidity-------
//     function replacementLiquidity(
//         address _holder,
//         ReplacementLiquidityType _type,
//         uint24 _fee,
//         int24 _tickLower,
//         int24 _tickUpper
//     ) external nonReentrant onlyVault(_holder) {
//         uint256 tokenId;
//         uint128 newLiquidity;
//         int24[2] memory priceSection = [int24(_tickLower), _tickUpper];
//         if (_type == ReplacementLiquidityType.Put) {
//             IOptionFacet.PutOrder memory putOrder = IOptionFacet(diamond)
//                 .getHolderPutOrder(_holder);
//             require(
//                 putOrder.optionHolder != address(0),
//                 "OptionModule:putOrder not exist"
//             );
//             require(
//                 putOrder.underlyingAssetType == 1,
//                 "OptionModule:underlyingAssetType error"
//             );
//             (tokenId, newLiquidity) = mintNewNft(
//                 putOrder.optionHolder,
//                 putOrder.underlyingAsset,
//                 putOrder.underlyingNftID,
//                 _fee,
//                 priceSection
//             );
//             IOptionFacet(diamond).setHolderPutOrderNftInfo(
//                 putOrder.optionHolder,
//                 tokenId,
//                 uint256(newLiquidity)
//             );
//             emit ReplacementLiquidity(
//                 _type,
//                 putOrder.optionHolder,
//                 _fee,
//                 _tickLower,
//                 _tickUpper,
//                 tokenId,
//                 newLiquidity
//             );
//         } else if (_type == ReplacementLiquidityType.Call) {
//             IOptionFacet.CallOrder memory callOrder = IOptionFacet(diamond)
//                 .getWriterCallOrder(_holder);
//             require(
//                 callOrder.optionWriter != address(0),
//                 "OptionModule:callOrder not exist"
//             );
//             require(
//                 callOrder.underlyingAssetType == 1,
//                 "OptionModule:underlyingAssetType error"
//             );
//             (tokenId, newLiquidity) = mintNewNft(
//                 callOrder.optionWriter,
//                 callOrder.underlyingAsset,
//                 callOrder.underlyingNftID,
//                 _fee,
//                 priceSection
//             );
//             IOptionFacet(diamond).setWriterCallOrderNftInfo(
//                 callOrder.optionWriter,
//                 tokenId,
//                 uint256(newLiquidity)
//             );
//             emit ReplacementLiquidity(
//                 _type,
//                 callOrder.optionWriter,
//                 _fee,
//                 _tickLower,
//                 _tickUpper,
//                 tokenId,
//                 newLiquidity
//             );
//         } else {
//             revert("OptionModule:ReplacementLiquidityType error");
//         }
//     }

//     function burnOldNft(
//         address _holder,
//         address _nft,
//         uint256 _nftId
//     ) internal returns (address[2] memory) {
//         INonfungiblePositionManager nonfungiblePositionManager = INonfungiblePositionManager(
//                 _nft
//             );
//         (
//             ,
//             ,
//             address token0,
//             address token1,
//             ,
//             ,
//             ,
//             uint128 liquidity,
//             ,
//             ,
//             ,

//         ) = nonfungiblePositionManager.positions(_nftId);
//         //transferFrom nft to current contract
//         IVaultFacet(diamond).setFuncWhiteList(
//             _holder,
//             bytes4(keccak256("transferFrom(address,address,uint256)")),
//             true
//         );
//         IVault(_holder).invokeTransferNft(_nft, address(this), _nftId);
//         IVaultFacet(diamond).setFuncBlackList(
//             _holder,
//             bytes4(keccak256("transferFrom(address,address,uint256)")),
//             false
//         );

//         //decreaseLiquidity
//         nonfungiblePositionManager.decreaseLiquidity(
//             INonfungiblePositionManager.DecreaseLiquidityParams({
//                 tokenId: _nftId,
//                 liquidity: liquidity,
//                 amount0Min: 0,
//                 amount1Min: 0,
//                 deadline: block.timestamp
//             })
//         );
//         //collect interestRate
//         nonfungiblePositionManager.collect(
//             INonfungiblePositionManager.CollectParams({
//                 tokenId: _nftId,
//                 recipientAddress: address(this),
//                 amount0Max: type(uint128).max,
//                 amount1Max: type(uint128).max
//             })
//         );

//         //burn nft
//         nonfungiblePositionManager.burn(_nftId);
//         address[2] memory tokens = [token0, token1];
//         return tokens;
//     }

//     function mintNewNft(
//         address _holder,
//         address _nft,
//         uint256 _nftId,
//         uint24 _fee,
//         int24[2] memory priceSection
//     ) internal returns (uint256, uint128) {
//         address[2] memory tokens = burnOldNft(_holder, _nft, _nftId);
//         uint256[2] memory amountDesireds = [uint256(0), 0];
//         amountDesireds[0] = IERC20(tokens[0]).balanceOf(address(this));
//         amountDesireds[1] = IERC20(tokens[1]).balanceOf(address(this));
//         IERC20(tokens[0]).approve(_nft, amountDesireds[0]);
//         IERC20(tokens[1]).approve(_nft, amountDesireds[1]);
//         INonfungiblePositionManager nonfungiblePositionManager = INonfungiblePositionManager(
//                 _nft
//             );
//         (uint256 tokenId, uint128 newLiquidity, , ) = nonfungiblePositionManager
//             .mint(
//                 INonfungiblePositionManager.MintParams({
//                     token0: tokens[0],
//                     token1: tokens[1],
//                     fee: _fee,
//                     tickLower: priceSection[0],
//                     tickUpper: priceSection[1],
//                     amount0Desired: amountDesireds[0],
//                     amount1Desired: amountDesireds[1],
//                     amount0Min: 0,
//                     amount1Min: 0,
//                     recipientAddress: _holder,
//                     deadline: block.timestamp
//                 })
//             );
//         return (tokenId, newLiquidity);
//     }

//     //----setting------
//     function setCollateralNft(
//         address _nft,
//         IOptionFacet.CollateralNftType _type
//     ) external onlyOwner {
//         IOptionFacet(diamond).setCollateralNft(_nft, _type);
//     }

//     function setOptionFeePlatformRecipient(
//         address _recipient
//     ) public onlyOwner {
//         IOptionFacet(diamond).setOptionFeePlatformRecipient(_recipient);
//     }

//     function setDomainHash(
//         string memory _name,
//         string memory _version,
//         address _contract
//     ) public onlyOwner {
//         bytes32 DomainInfoTypeHash = keccak256(
//             "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
//         );
//         bytes32 _domainHash = keccak256(
//             abi.encode(
//                 DomainInfoTypeHash,
//                 keccak256(bytes(_name)),
//                 keccak256(bytes(_version)),
//                 block.chainid,
//                 _contract
//             )
//         );
//         IOptionFacet(diamond).setDomainHash(_domainHash);
//     }
// }
