pragma solidity 0.6.10;
import {ISetToken} from "@setprotocol/set-protocol-v2/contracts/interfaces/ISetToken.sol";
pragma experimental "ABIEncoderV2";

interface IDelegatedManagerFactory {
    function createSetAndManager(
        address[] memory _components,
        int256[] memory _units,
        string memory _name,
        string memory _symbol,
        address _owner,
        address _methodologist,
        address[] memory _modules,
        address[] memory _operators,
        address[] memory _assets,
        address[] memory _extensions
    ) external returns (ISetToken, address);

    function initialize(
        ISetToken _setToken,
        uint256 _ownerFeeSplit,
        address _ownerFeeRecipient,
        address[] memory _extensions,
        bytes[] memory _initializeBytecode
    ) external;
}
