pragma solidity ^0.8.6;
import {JasperAsset} from "./asset_nft.sol";
import "./jasper_lending.sol";
import {ERC721} from "./tokens/erc721.sol";

import "openzeppelin-contracts-V4/access/Ownable.sol";
import "openzeppelin-contracts-V4/token/ERC20/IERC20.sol";

contract Jasper_Protocol_Creator is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    /* ============ Events ============ */
    event TokenCreated(
        address indexed _Token,
        address indexed _protocol,
        uint256 indexed _price
    );

    function create(
        IERC20 _paymentToken,
        uint256 _price,
        ERC721 _collateral,
        IERC20 _collateral_erc20,
        uint256 _tokenId,
        uint256 _tokenAmount,
        uint256 _interest_per_sec,
        uint256 _unlockTime,
        address _receiver
    ) external returns (address) {
        Jasper_Protocol protocol = new Jasper_Protocol(
            _paymentToken,
            _price,
            _collateral,
            _collateral_erc20,
            _tokenId,
            _tokenAmount,
            _interest_per_sec,
            _unlockTime,
            _receiver
        );
        if (_tokenId == 0) {
            _collateral_erc20.safeTransferFrom(
                msg.sender,
                address(protocol),
                _tokenAmount
            );
        } else {
            _collateral.transferFrom(msg.sender, address(protocol), _tokenId);
        }

        emit TokenCreated(address(_collateral), address(protocol), _price);
        return address(protocol);
    }
}
