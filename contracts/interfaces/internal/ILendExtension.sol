// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {ILendFacet} from "./ILendFacet.sol";
interface ILendExtension {
    enum ReplacementLiquidityType{
         Put,
         Call
    }
    event ReplacementLiquidity(ReplacementLiquidityType _type,address _holder,uint24 _fee,int24 _tickLower,int24 _tickUpper,uint256 _tokenId,uint128 _newLiquidity);
    function replacementLiquidity(address _holder,ReplacementLiquidityType _type,uint24 _fee,int24 _tickLower,int24 _tickUpper) external;
}
