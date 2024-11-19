// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../interfaces/external/INFTFreeOptionPool.sol";

contract NFTRegister is
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable
{
    // Define NFTInfo struct
    struct NFTInfo {
        uint256 nftId;
        string inscriptionId;
    }

    // Modify global variable
    mapping(address => NFTInfo) private _ownerToNftInfo;

    // Modify event to include inscriptionId
    event NftOwnerRegistered(address indexed owner, address indexed registrar, uint256 nftId, string inscriptionId);

    // Define OPERATOR_ROLE
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Interface variable for NFTFreeOptionPool
    INFTFreeOptionPool public nftFreeOptionPool;

    // Add expiry date as a state variable
    uint256 private _expiryDate;

    uint256 private _nftDiscount;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function __NFTRegister_init(
        address _nftFreeOptionPool
    ) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);

        // Initialize nftFreeOptionPool
        nftFreeOptionPool = INFTFreeOptionPool(_nftFreeOptionPool);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // Modified registerNftOwner function
    function registerNftOwner(address ownerAddress, uint256 nftId, string memory inscriptionId) public onlyRole(OPERATOR_ROLE) {
        require(ownerAddress != address(0), "Invalid owner address");
        require(nftId > 0, "Invalid NFT ID");
        require(bytes(inscriptionId).length > 0, "Invalid inscription ID");
        require(_ownerToNftInfo[ownerAddress].nftId == 0, "Address already registered");
        
        _ownerToNftInfo[ownerAddress] = NFTInfo(nftId, inscriptionId);
        
        // Use the _expiryDate for addNFTDiscountToUser
        require(_expiryDate > block.timestamp, "Expiry date not set or expired");
        nftFreeOptionPool.addNFTDiscountToUser(ownerAddress, _nftDiscount);
        
        emit NftOwnerRegistered(ownerAddress, msg.sender, nftId, inscriptionId);
    }

    function setNFTDiscount(uint256 nftId) external onlyRole(OPERATOR_ROLE) {
       _nftDiscount = nftId;
    }

    // Modify getOwnerNftId function and add new getter functions
    function getOwnerNftInfo(address ownerAddress) public view returns (uint256, string memory) {
        NFTInfo memory info = _ownerToNftInfo[ownerAddress];
        return (info.nftId, info.inscriptionId);
    }

    function getOwnerNftId(address ownerAddress) public view returns (uint256) {
        return _ownerToNftInfo[ownerAddress].nftId;
    }

    function getOwnerInscriptionId(address ownerAddress) public view returns (string memory) {
        return _ownerToNftInfo[ownerAddress].inscriptionId;
    }

    // Add functions to grant and revoke OPERATOR_ROLE
    function grantOperatorRole(address account) external onlyOwner {
        grantRole(OPERATOR_ROLE, account);
    }

    function revokeOperatorRole(address account) external onlyOwner {
        revokeRole(OPERATOR_ROLE, account);
    }

    function batchRegisterNftOwners(
        address[] calldata ownerAddresses,
        uint256[] calldata nftIds,
        string[] calldata inscriptionIds
    ) external onlyRole(OPERATOR_ROLE) {
        require(
            ownerAddresses.length == nftIds.length && 
            nftIds.length == inscriptionIds.length,
            "Input arrays must have the same length"
        );
        
        for (uint256 i = 0; i < ownerAddresses.length; i++) {
            registerNftOwner(ownerAddresses[i], nftIds[i], inscriptionIds[i]);
        }
    }

    // Function to check if an address is registered
    function isAddressRegistered(address ownerAddress) public view returns (bool) {
        return _ownerToNftInfo[ownerAddress].nftId != 0;
    }

    // Add a function to set the _expiryDate
    function setExpiryDate(uint256 newExpiryDate) external onlyOwner {
        require(newExpiryDate > block.timestamp, "Expiry date must be in the future");
        _expiryDate = newExpiryDate;
    }

    // Add a function to get the current _expiryDate
    function getExpiryDate() public view returns (uint256) {
        return _expiryDate;
    }

    /**
     * @notice Set the NFT Free Option Pool contract address
     * @param _address The address of NFT Free Option Pool contract
     * @dev Only callable by operator
     */
    function setNftFreeOptionPool(address _address) public onlyRole(OPERATOR_ROLE) {
        nftFreeOptionPool = INFTFreeOptionPool(_address);
    }

    /**
     * @notice Get the NFT Free Option Pool contract address
     * @return The address of current NFT Free Option Pool contract
     */
    function getNftFreeOptionPool() public view returns (address) {
        return address(nftFreeOptionPool);
    }
}
