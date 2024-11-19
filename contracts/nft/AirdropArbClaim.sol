// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "../interfaces/external/IERC20.sol";

contract AirdropArbClaim is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    mapping(address => bool) public operators;

    address public arbTokenAddress;  // usdt contract address
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

    function initialize(address arbAddress) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        arbTokenAddress = arbAddress;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setOperator(address _op, bool allow) public onlyOwner{
        operators[_op] = allow;
    }

    // Set USDT Token
    function setArbTokenAddress(address token) public onlyOperator{
        arbTokenAddress = token;
    }

    function settle(address[] memory addressList) public onlyOperator {

    
        require(totalClaimCount + addressList.length <= 10000, "Exceeds the maximum number of claims");

        uint256 total = 0;
        uint256 amount = 2 * 10 ** 18;
        for (uint i = 0; i < addressList.length; i++) {

            require(totalClaimInfo[addressList[i]] == 0, "Duplicated address");

            if(totalClaimCount >= 5000){
                amount = 1 * 10 ** 18;
            }


            claimInfo[addressList[i]] += amount;
            totalClaimInfo[addressList[i]] += amount;
            total += amount;

            totalClaimCount++;
        }

        totalClaimAmount += total;

        emit AddAmount(total);
    }

    function claim() public {

        address user = msg.sender;
        uint256 amount = claimInfo[user];

        require(amount > 0, "Can not claim 0");
        require(IERC20(arbTokenAddress).transfer(user, amount), "Arb Token Transfer Failed.");

        claimInfo[user] = 0;
        totalClaimAmount -= amount;

        emit Claim(user, amount);
    }

    function minusAmount(address user, uint256 amount) public onlyOperator {
        claimInfo[user] -= amount;
        totalClaimInfo[user] -= amount;
        totalClaimAmount -= amount;
        totalClaimCount--;
    }

    function adminSettle(address[] memory _users, uint256 _amount, uint256 _count) public onlyOwner {
        for (uint i = 0; i < _users.length; i++) {
            claimInfo[_users[i]] = _amount;
            totalClaimInfo[_users[i]] = _amount;
        }

        totalClaimAmount += _count;
    }
}