// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {INFTFreeOptionPool} from "../interfaces/external/INFTFreeOptionPool.sol";


contract JVTB is Initializable, UUPSUpgradeable, OwnableUpgradeable, ERC1155SupplyUpgradeable {
    using Strings for uint256;
    string public baseURI;

    mapping(string => uint256) public promoteCodeList;
    mapping(address => mapping(uint256 => bool)) public hasMint;

    uint256 public totalBalance;
    mapping(address => bool) public globalHasMint;

    address public nftFreeOptionPoolAddress;
    address public operator;

    uint256 public totalMintCount;

    event MintJasperNFT(address indexed user, uint256 indexed tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyOperator(){
        require(msg.sender == operator, "You are not operator");
        _;
    }

    function initialize() initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ERC1155Supply_init();

        totalBalance = 0;
        baseURI = "https://jaspervault.s3.ap-southeast-1.amazonaws.com/meta/1155/";
        operator = address(0x430A91651dD2D372F8B670F98056736c2c093E2f);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function name() virtual public pure returns (string memory) {
        return "Jasper Vault Trading Benefits";
    }

    function symbol() virtual public pure returns (string memory) {
        return "JVTB";
    }

    function uri(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, id.toString(), ".json"));
    }

    function setOperator(address _op) public onlyOwner{
        operator = _op;
    }

    function setBaseURI(string memory _baseURI) public onlyOperator {
        baseURI = _baseURI;
    }

    function setNftFreeOptionPoolAddress(address _nftFreeOptionPoolAddress) public onlyOperator {
        nftFreeOptionPoolAddress = _nftFreeOptionPoolAddress;
    }

    function setTotalMintCount(uint256 _mintCount) public onlyOperator{
        totalMintCount = _mintCount;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) pure external returns (bytes4) {
        return 0xf23a6e61;
    }
    
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) pure external returns (bytes4) {
        return 0xbc197c81;
    }

    function mint(string memory promoteCode) public {
        
        uint256 tokenId = promoteCodeList[promoteCode];
        require(tokenId > 0, "Invalid Promote Code");
        
        require(globalHasMint[msg.sender] == false, "Only Mint Once Per Address");
    
        _mint(msg.sender, tokenId, 1, new bytes(1));

        promoteCodeList[promoteCode] = 0;
        hasMint[msg.sender][tokenId] = true;
        globalHasMint[msg.sender] = true;
        totalMintCount += 1;

        INFTFreeOptionPool(nftFreeOptionPoolAddress).addNFTDiscountToUser(msg.sender, tokenId);

        emit MintJasperNFT(msg.sender, tokenId);
    }

    function setPromoteList(string[] memory promoteCodes, uint256 tokenId) public onlyOperator{

        require(tokenId > 0, "Invalid Token Id");
        for(uint256 i=0;i<promoteCodes.length;i++){

            string memory promoteCode = promoteCodes[i];
            require(promoteCodeList[promoteCode] == 0, promoteCode);
            promoteCodeList[promoteCode] = tokenId;

            totalBalance += 1;
        }
    }

    function removePromotionCodes(string[] memory promoteCodes) public onlyOperator{

        for(uint256 i=0;i<promoteCodes.length;i++){

            string memory promoteCode = promoteCodes[i];
            promoteCodeList[promoteCode] = 0;
            totalBalance -= 1;
        }
    }

    function setAddressHasMint(address[] memory addressArray, uint256 tokenId, bool _hasMint) public onlyOperator{

        for(uint256 i=0;i<addressArray.length;i++){

            address a = addressArray[i];
            hasMint[a][tokenId] = _hasMint;
            globalHasMint[a] = _hasMint;
        }
    }

    function adminMint(uint256 tokenId, uint256 count) public onlyOperator{

        totalBalance += count;
        _mint(msg.sender, tokenId, count, new bytes(1));
    }

    function stringToBytes(string memory str) internal pure returns (bytes memory) {
        return bytes(str);
    }

    function bytesToString(bytes memory byteArray) internal pure returns (string memory) {
        return string(byteArray);
    }

    function setEncryptPromoteList(string[] memory promoteCodes, uint256 tokenId) public onlyOperator{

        require(tokenId > 0, "Invalid Token Id");
        for(uint256 i=0;i<promoteCodes.length;i++){

            string memory encryptPromoteCode = promoteCodes[i];
            string memory promoteCode = decryptString(encryptPromoteCode);

            require(promoteCodeList[promoteCode] == 0, promoteCode);
            promoteCodeList[promoteCode] = tokenId;

            totalBalance += 1;
        }
    }

    function decryptString(string memory data) public pure returns (string memory) {

        bytes memory dataByteArray = stringToBytes(data);

        for(uint8 i=0;i<dataByteArray.length;i++){
            
            bytes1 b = dataByteArray[i];
            bytes1 decreaseB = decreaseByte(b, i+1);
            dataByteArray[i] = decreaseB;
        }

        return bytesToString(dataByteArray);
    }

    function decreaseByte(bytes1 b, uint8 decrease) public pure returns (bytes1 a) {
        return bytes1(uint8(b) - decrease);
    }
}