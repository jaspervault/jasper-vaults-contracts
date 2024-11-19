// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "../interfaces/external/IERC20.sol";

contract AirdropTradeClaim is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    mapping(address => bool) public operators;

    address public usdtTokenAddress;  // usdt contract address
    uint256 public totalClaimAmount;
    uint256 public totalClaimCount;

    //User Address => Claim amount
    mapping(address => uint256) public claimInfo;
    //User Address => Total Claim Amount
    mapping(address => uint256) public totalClaimInfo;

    event AddAmount(uint256 indexed amount);
    event Claim(address indexed user, uint256 indexed amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyOperator(){
        require(operators[msg.sender] == true, "You are not operator");
        _;
    }

    function initialize(address usdtAddress) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        usdtTokenAddress = usdtAddress;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setOperator(address _op, bool allow) public onlyOwner{
        operators[_op] = allow;
    }

    // Set USDT Token
    function setUSDTokenAddress(address token) public onlyOperator{
        usdtTokenAddress = token;
    }

    function settle(address[] memory addressList, uint256[] memory amountList) public onlyOperator {

        require(addressList.length == amountList.length, "address list length mismatch amount list length");
        require(totalClaimCount + addressList.length <= 10000, "Exceeds the maximum number of claims");

        uint256 total = 0;
        for (uint i = 0; i < addressList.length; i++) {

            require(totalClaimInfo[addressList[i]] == 0, "Duplicated address");

            claimInfo[addressList[i]] += amountList[i];
            totalClaimInfo[addressList[i]] += amountList[i];
            total += amountList[i];

            totalClaimCount++;
        }

        totalClaimAmount += total;

        emit AddAmount(total);
    }

    function claim() public {

        address user = msg.sender;
        uint256 amount = claimInfo[user];

        require(amount > 0, "Can not claim 0");
        require(IERC20(usdtTokenAddress).transfer(user, amount), "USDT Token Transfer Failed.");

        claimInfo[user] = 0;
        totalClaimAmount -= amount;

        emit Claim(user, amount);
    }

    function minusAmount(address user, uint256 amount) public onlyOperator {
        claimInfo[user] -= amount;
        totalClaimInfo[user] -= amount;
        totalClaimAmount -= amount;
    }
}