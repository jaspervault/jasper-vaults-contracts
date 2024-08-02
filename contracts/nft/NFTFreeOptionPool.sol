// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IOptionModuleV2} from "../interfaces/internal/IOptionModuleV2.sol";
import {IVault} from "../interfaces/internal/IVault.sol";
import {IERC20} from "../interfaces/external/IERC20.sol";

contract NFTFreeOptionPool is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    address public optionModuleContractAddress;
    address public nftContractAddress;

    mapping(bytes32 => uint256) public nftDiscountIds;
    mapping(uint256 => bytes32) public nftDiscounts;
    mapping(uint256 => uint256[]) public nftIdToDiscountId;
    mapping(address => mapping(uint256 => uint256)) public userDiscounts;

    struct NFTDiscount{
        address optionAsset;
        uint256 quantity;
        uint256 productType;
        uint8 optionType;
    }

    mapping(address => bool) public operators;
    event SubmitFreeAmount(address indexed user, address indexed tokenAddress, uint256 indexed amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyOperator(){
        require(operators[msg.sender] == true, "You are not operator");
        _;
    }

    function initialize(address _optionModule, address _nftContract) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        optionModuleContractAddress = _optionModule;
        nftContractAddress = _nftContract;
    }

    function setOperator(address _op, bool allow) public onlyOwner{
        operators[_op] = allow;
    }

    function setOptionModuleContractAddress(address _address) public onlyOperator {
        optionModuleContractAddress = _address;
    }

    function setNftContractAddress(address _address) public onlyOperator {
        nftContractAddress = _address;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function encodeNFTDiscount(NFTDiscount memory _discount) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_discount.optionAsset, _discount.quantity, _discount.productType, _discount.optionType));
    }

    function addNFTDiscount(NFTDiscount memory _discount, uint256 _discountId) public onlyOperator{
        bytes32 hash = encodeNFTDiscount(_discount);
        require(nftDiscountIds[hash] == 0, "NFTDiscountPool: discount already exists");
        nftDiscountIds[hash] = _discountId;
        nftDiscounts[_discountId] = hash;
    }

    function removeNFTDiscount(bytes32 _hash) public onlyOperator{
        uint256 discountId = nftDiscountIds[_hash];
        require(discountId != 0, "NFTDiscountPool: discount not exists");
        delete nftDiscountIds[_hash];
        delete nftDiscounts[discountId];
    }

    function setNFTToDiscount(uint256 _nftId, uint256[] memory _discountIds) public onlyOperator{
        nftIdToDiscountId[_nftId] = _discountIds;
    }

    function addNFTDiscountToUser(address _user, uint256 _nftId) public{

        uint256[] memory discounts = nftIdToDiscountId[_nftId];

        require(discounts.length > 0, "NFTDiscountPool: discount not exists");

        bool allow = operators[msg.sender];
        if(msg.sender == nftContractAddress){
            allow = true;
        }

        require(allow == true, "NFTDiscountPool: only nft contract or operator can call this function");
        
        for(uint256 i = 0; i < discounts.length; i++){
            uint256 discountId = discounts[i];
            userDiscounts[_user][discountId] ++;
        }
    }

    function setDiscountToUser(address[] memory _user, uint256[] memory discountIds, uint256[] memory counts) public onlyOperator{

        require(_user.length == discountIds.length, "Error length");
        require(counts.length == discountIds.length, "Error length in count");
        
        for(uint256 i = 0; i < _user.length; i++){
            address user = _user[i];
            uint256 discountId = discountIds[i];
            userDiscounts[user][discountId] = counts[i];
        }
    }

    function getUserDiscount(
        address optionAsset,
        uint256 quantity,
        uint256 productType,
        uint8 optionType,
        address eoaAddress
    ) public view returns (uint256 discountCount){

        NFTDiscount memory discount = NFTDiscount(
            optionAsset,
            quantity,
            productType,
            optionType
        );

        bytes32 discountHash = encodeNFTDiscount(discount);
        uint256 discountId = nftDiscountIds[discountHash];
        return userDiscounts[eoaAddress][discountId];
    }

    function getFreeAmount(IOptionModuleV2.ManagedOrder memory _optionOrder) public view returns (uint256 amount){

        address _vault = _optionOrder.recipient;
        address eoaAddress = IVault(_vault).owner();

        NFTDiscount memory discount = NFTDiscount(
            _optionOrder.premiumSign.optionAsset,
            _optionOrder.quantity,
            _optionOrder.premiumSign.productType,
            2
        );

        bytes32 discountHash = encodeNFTDiscount(discount);
        uint256 discountId = nftDiscountIds[discountHash];

        if(discountId == 0){
            return 0;
        }

        uint256 discountAmount = 0;
        uint256 discountCount = userDiscounts[eoaAddress][discountId];
        if(discountCount > 0){
            discountAmount = _optionOrder.premiumSign.premiumFee * _optionOrder.quantity / 10**18;
        }

        return discountAmount;
    }

    function submitFreeAmount(IOptionModuleV2.ManagedOrder memory _optionOrder, uint256 amount) public returns (bool ok){

        require(msg.sender == optionModuleContractAddress, "NFTDiscountPool: only option module contract can call this function");
        
        address _vault = _optionOrder.recipient;
        address eoaAddress = IVault(_vault).owner();

        NFTDiscount memory discount = NFTDiscount(
            _optionOrder.premiumSign.optionAsset,
            _optionOrder.quantity,
            _optionOrder.premiumSign.productType,
            2
        );

        bytes32 discountHash = encodeNFTDiscount(discount);
        uint256 discountId = nftDiscountIds[discountHash];

        if(discountId == 0){
            return true;
        }

        uint256 discountCount = userDiscounts[eoaAddress][discountId];
        if(discountCount > 0){
            userDiscounts[eoaAddress][discountId] = discountCount - 1;
        }

        emit SubmitFreeAmount(eoaAddress, _optionOrder.premiumSign.premiumAsset, amount);
        return true;
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external returns (bytes memory result) {

        require(msg.sender == optionModuleContractAddress, "NFTDiscountPool: only option module contract can call this function");

        address[] memory _dest = new address[](1);
        _dest[0] = dest;
        result = _call(dest, value, func);
    }

    function _call(
        address target,
        uint256 value,
        bytes memory data
    ) internal returns (bytes memory) {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        return result;
    }
}
