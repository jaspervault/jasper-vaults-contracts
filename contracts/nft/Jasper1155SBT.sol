// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {IOptionModuleV2} from "../interfaces/internal/IOptionModuleV2.sol";
import {IVault} from "../interfaces/internal/IVault.sol";
import {IERC20} from "../interfaces/external/IERC20.sol";
import {IPlatformFacet} from "../interfaces/internal/IPlatformFacet.sol";

/**
 * @title JSBT (Jasper Soul Bound Token)
 * @dev This contract implements a Soul Bound Token (SBT) based on the ERC1155 standard.
 * It is non-transferable and can only be minted or burned by an authorized operator.
 * 
 * nft id 1: Moonlight Box
 * nft id 2: Reality Stone
 * nft id 3: Power Stone
 * 
 */
contract JSBT is Initializable, UUPSUpgradeable, OwnableUpgradeable, ERC1155SupplyUpgradeable {
    using Strings for uint256;

    string public baseURI;
    mapping(address => bool) public operators;
    address public optionModuleContractAddress;
    uint256 public totalBalance;

    // New variables for validity period
    uint256 public startTime;
    uint256 public endTime;

    // Option order type -> nft id
    mapping(bytes32 => uint256) public nftDiscountIds;
    mapping(uint256 => bytes32) public nftDiscounts;
    struct NFTDiscount{
        address optionAsset;
        uint256 quantity;
        uint256 productType;
        uint8 optionType;
    }

    //User about to use nft id
    mapping(address => uint256) public userUseNftId;

    address public diamond;

    event SubmitFreeAmount(address indexed user, address indexed tokenAddress, uint256 indexed amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Modifier to restrict access to the operator only
     */
    modifier onlyOperator(){
        require(operators[msg.sender] == true, "You are not operator");
        _;
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner and operator
     * @param _baseURI The base URI for token metadata
     * @param _startTime The start time of the validity period
     * @param _endTime The end time of the validity period
     */
    function initialize(string memory _baseURI, uint256 _startTime, uint256 _endTime, address _optioinModuleContractAddress, address _operator) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ERC1155Supply_init();
        baseURI = _baseURI;
        startTime = _startTime;
        endTime = _endTime;
        optionModuleContractAddress = _optioinModuleContractAddress;
        operators[_operator] = true;
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function encodeNFTDiscount(NFTDiscount memory _discount) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_discount.optionAsset, _discount.quantity, _discount.productType, _discount.optionType));
    }

    function addNFTDiscount(NFTDiscount memory _discount, uint256 _discountId) public onlyOperator{
        bytes32 _hash = encodeNFTDiscount(_discount);
        //require(nftDiscountIds[_hash] == 0, "JasperSBT: discount already exists");
        nftDiscountIds[_hash] = _discountId;
        nftDiscounts[_discountId] = _hash;
    }

    function removeNFTDiscountIds(bytes32 _hash) public onlyOperator{
        delete nftDiscountIds[_hash];
    }

    function removeNFTDiscount(uint256 discountId) public onlyOperator{
        delete nftDiscounts[discountId];
    }

    /**
     * @dev Returns the name of the token
     * @return string The name of the token
     */
    function name() virtual public pure returns (string memory) {
        return "Jasper Soul Bound Token";
    }

    /**
     * @dev Returns the symbol of the token
     * @return string The symbol of the token
     */
    function symbol() virtual public pure returns (string memory) {
        return "JSBT";
    }

    /**
     * @dev Returns the URI for a given token ID
     * @param id The ID of the token
     * @return string The URI for the given token ID
     */
    function uri(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, id.toString(), ".json"));
    }

    /**
     * @dev Sets a new operator address
     * @param _op The address of the new operator
     */
    function setOperator(address _op, bool allow) public onlyOwner{
        operators[_op] = allow;
    }

    /**
     * @dev Sets a new base URI for token metadata
     * @param _baseURI The new base URI
     */
    function setBaseURI(string memory _baseURI) public onlyOperator {
        baseURI = _baseURI;
    }

    /**
     * @dev Mints new tokens to a specified address (only callable by operator)
     * @param to The address to mint tokens to
     * @param tokenId The ID of the token to mint
     * @param amount The amount of tokens to mint
     */
    function adminMint(address to, uint256 tokenId, uint256 amount) public onlyOperator {
        totalBalance += amount;
        _mint(to, tokenId, amount, "");
    }
    
    /**
     * @dev Overrides the safeTransferFrom function to prevent transfers
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        revert("SBT: transfer is not allowed");
    }

    /**
     * @dev Overrides the safeBatchTransferFrom function to prevent batch transfers
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        revert("SBT: batch transfer is not allowed");
    }

    /**
     * @dev Overrides the setApprovalForAll function to prevent approvals
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        revert("SBT: approval is not allowed");
    }

    /**
     * @dev Allows burning of SBTs only by operators
     * @param account The address of the token holder
     * @param id The ID of the token to burn
     * @param amount The amount of tokens to burn
     */
    function adminBurn(address account, uint256 id, uint256 amount) public virtual onlyOperator {
        require(balanceOf(account, id) >= amount, "SBT: burn amount exceeds balance");
        _burn(account, id, amount);
        totalBalance -= amount;
    }

    // New function to check NFT validity
    function isValidNFT(address _owner, uint256 _tokenId) public view returns (bool) {
        // return (
        //     balanceOf(_owner, _tokenId) > 0 &&
        //     block.timestamp >= startTime &&
        //     block.timestamp <= endTime
        // );
        return (balanceOf(_owner, _tokenId) > 0);
    }

    // New function to set validity period
    function setValidityPeriod(uint256 _startTime, uint256 _endTime) public onlyOperator {
        require(_startTime < _endTime, "Invalid time range");
        startTime = _startTime;
        endTime = _endTime;
    }

    function setAboutToUseNftId(uint256 _nftId) public{

        address sender = msg.sender;

        if(isContract(sender)){
            address vault1 = sender;
            require(IPlatformFacet(diamond).getIsVault(vault1), "Not Platform Vault");
            sender = IVault(vault1).owner();
        }

        if(isValidNFT(sender, _nftId)){
            userUseNftId[sender] = _nftId;
        }
    }

    /**
     * @dev Batch mints new tokens to specified addresses (only callable by operator)
     * @param to Array of addresses to mint tokens to
     * @param tokenIds Array of token IDs to mint
     * @param amounts Array of amounts of tokens to mint
     */
    function adminMintBatch(address[] memory to, uint256[] memory tokenIds, uint256[] memory amounts) public onlyOperator {
        require(to.length == tokenIds.length && to.length == amounts.length, "Array lengths do not match");
        
        for (uint256 i = 0; i < to.length; i++) {
            totalBalance += amounts[i];
            _mint(to[i], tokenIds[i], amounts[i], "");
        }
    }
    
    function getFreeAmount(
        IOptionModuleV2.ManagedOrder memory _optionOrder
    ) public view returns (uint256 amount){

        address _vault = _optionOrder.recipient;
        address eoaAddress = IVault(_vault).owner();

        NFTDiscount memory discount = NFTDiscount(
            _optionOrder.premiumSign.optionAsset,
            _optionOrder.quantity,
            _optionOrder.premiumSign.productType,
            2
        );
        bytes32 discountHash = encodeNFTDiscount(discount);

        uint256 aboutToUseNftId = userUseNftId[eoaAddress];
        if(aboutToUseNftId == 0){
            return 0;
        }

        bytes32 nftDiscountHash = nftDiscounts[aboutToUseNftId];
        if(nftDiscountHash != discountHash){
            return 0;
        }

        uint256 discountAmount = 0;
        
        if(isValidNFT(eoaAddress, aboutToUseNftId)){
            discountAmount = _optionOrder.premiumSign.premiumFee * _optionOrder.quantity / 10**18;
        }

        return discountAmount;
    }

    function submitFreeAmount(
        IOptionModuleV2.ManagedOrder memory _optionOrder, 
        uint256 amount
    ) public returns (bool ok){

        require(msg.sender == optionModuleContractAddress, "JasperSBT: only option module contract can call this function");
        
        address _vault = _optionOrder.recipient;
        address eoaAddress = IVault(_vault).owner();

        //Find the valid discount id
        NFTDiscount memory discount = NFTDiscount(
            _optionOrder.premiumSign.optionAsset,
            _optionOrder.quantity,
            _optionOrder.premiumSign.productType,
            2
        );

        bytes32 discountHash = encodeNFTDiscount(discount);

        uint256 aboutToUseNftId = userUseNftId[eoaAddress];
        if(aboutToUseNftId == 0){
            return false;
        }

        bytes32 nftDiscountHash = nftDiscounts[aboutToUseNftId];
        if(nftDiscountHash != discountHash){
            return false;
        }

        if(isValidNFT(eoaAddress, aboutToUseNftId)){
            _burn(eoaAddress, aboutToUseNftId, 1);
            userUseNftId[eoaAddress] = 0;
            totalBalance -= 1;
        }

        emit SubmitFreeAmount(eoaAddress, _optionOrder.premiumSign.premiumAsset, amount);
        return true;
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external returns (bytes memory result) {
        require(msg.sender == optionModuleContractAddress, "JasperSBT: only option module contract can call this function");
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

    receive() external payable {}

    function setDiamond(address _diamond) public onlyOperator {
        diamond = _diamond;
    }

    function isContract(address _addr) public view returns (bool) {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(_addr)
        }
        return codeSize > 0;
    }
}
