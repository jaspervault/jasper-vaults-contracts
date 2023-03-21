pragma solidity 0.6.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SetToken} from "./protocol/SetToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Jasper_Issuer is Ownable {
    IERC20 public paymentToken;

    function buy(SetToken fund, uint256 _quantity) public payable {}

    function issur_fund() public {}

    function update_payment(IERC20 _paymentToken) public onlyOwner {
        paymentToken = _paymentToken;
    }
}
