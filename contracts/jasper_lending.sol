pragma solidity ^0.8.6;

import "openzeppelin-contracts-V4/token/ERC20/IERC20.sol";
import "openzeppelin-contracts-V4/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts-V4/utils/math/SafeMath.sol";
import "openzeppelin-contracts-V4/utils/Address.sol";
import {ERC721} from "./tokens/erc721.sol";

contract Jasper_Protocol {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IERC20 public paymentToken;
    ERC721 public collateral;
    IERC20 public collateral_erc20;
    uint256 public price;
    uint256 public tokenId;
    uint256 public tokenAmount;
    uint256 public interest_per_sec;
    uint256 public start_datetime;
    uint256 public unlockTime;
    address public borrower;
    address public lender;

    constructor(
        IERC20 _paymentToken,
        uint256 _price,
        ERC721 _collateral,
        IERC20 _collateral_erc20,
        uint256 _tokenId,
        uint256 _tokenAmount,
        uint256 _interest_per_sec,
        uint256 _unlockTime,
        address _borrower
    ) {
        paymentToken = _paymentToken;
        price = _price;
        collateral = _collateral;
        collateral_erc20 = _collateral_erc20;
        tokenId = _tokenId;
        tokenAmount = _tokenAmount;
        interest_per_sec = _interest_per_sec;
        unlockTime = _unlockTime;
        borrower = _borrower;
        start_datetime = 0;
    }

    function get_interest() public view returns (uint256) {
        if (start_datetime == 0) {
            return 0;
        } else {
            return block.timestamp.sub(start_datetime).mul(interest_per_sec);
        }
    }

    function supply() public payable {
        if (address(paymentToken) == address(0)) {
            payable(msg.sender).transfer(msg.value);
        } else {
            paymentToken.safeTransferFrom(address(msg.sender), borrower, price);
        }
        lender = address(msg.sender);
        start_datetime = block.timestamp;
    }

    function repay() public payable {
        if (block.timestamp < unlockTime) {
            require(
                address(msg.sender) == borrower,
                "you are not the nft owner"
            );
        }
        uint256 balance = paymentToken.balanceOf(address(msg.sender));
        require(balance >= price.add(get_interest()), "I need more!");
        if (address(paymentToken) == address(0)) {
            payable(msg.sender).transfer(msg.value);
        } else {
            paymentToken.safeTransferFrom(
                address(msg.sender),
                address(lender),
                price.add(get_interest())
            );
        }
        if (tokenAmount == 0) {
            collateral.transferFrom(address(this), msg.sender, tokenId);
        } else {
            collateral_erc20.approve(address(this), tokenAmount);
            collateral_erc20.safeTransferFrom(
                address(this),
                msg.sender,
                tokenAmount
            );
        }
    }
}
