// SPDX-License-Identifier: GPL-3.0
pragma solidity  ^0.8.12;

/* solhint-disable reason-string */



import "./core/BasePaymaster.sol";

interface IOwnable{
    function owner() external returns(address);
}

interface IUniswapV2Router {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
}


interface IERC20{
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns(bool);
}


/**
 * A sample paymaster that defines itself as a token to pay for gas.
 * The paymaster IS the token to use, since a paymaster cannot use an external contract.
 * Also, the exchange rate has to be fixed, since it can't reference an external Uniswap or other exchange contract.
 * subclass should override "getTokenValueOfEth" to provide actual token exchange rate, settable by the owner.
 * Known Limitation: this paymaster is exploitable when put into a batch with multiple ops (of different accounts):
 * - while a single op can't exploit the paymaster (if postOp fails to withdraw the tokens, the user's op is reverted,
 *   and then we know we can withdraw the tokens), multiple ops with different senders (all using this paymaster)
 *   in a batch can withdraw funds from 2nd and further ops, forcing the paymaster itself to pay (from its deposit)
 * - Possible workarounds are either use a more complex paymaster scheme (e.g. the DepositPaymaster) or
 *   to whitelist the account and the called method ids.
 */
contract VaultPaymaster is BasePaymaster{
    //calculated cost of the postOp
    uint256 constant public COST_OF_POST = 15000;

    //account token account
    mapping(address=>uint256)  public  user2balance;

    IUniswapV2Router public immutable router;

    address public immutable eth;

    event Deposit(address user,address token,uint256 amount);

    event Withdraw(address user,address token,uint256 amount);

    constructor(IEntryPoint _entryPoint,IUniswapV2Router _router) BasePaymaster(_entryPoint) {
          router=_router;
          eth=_router.WETH();
    }

    //deposit   Eth
   function  depositEth()  external payable {
        require(msg.value>0,"deposit balance less than zero");
        uint256 preBalance=user2balance[msg.sender];
        deposit();
        user2balance[msg.sender]=preBalance+msg.value;
        emit Deposit(msg.sender,eth,msg.value);
   }

   function withdrawEth(uint256 _amount) external payable {
         uint256 preBalance=user2balance[msg.sender];
         require(preBalance>=_amount,"withdraw eth greater than balance");
         user2balance[msg.sender]=preBalance-_amount;
         withdrawTo(payable( msg.sender),_amount);
         emit Withdraw(msg.sender,eth,_amount);
   }

   //deposit  Token
   function depositToken(IERC20 _token, uint256 _amount) external  {
         require(_amount>0,"amount less than zero");     
         _token.transferFrom(msg.sender, address(this), _amount);
         _token.approve(address(router),_amount);
         uint256 swapNum=_swapExactTokensForETH(_token,_amount);
         deposit();
         uint256 preBalance=user2balance[msg.sender];  
         user2balance[msg.sender]=preBalance+swapNum;
         emit Deposit(msg.sender,address(_token),_amount);
   }


   function withdrawToken(IERC20 _receiveToken,uint256 _amount) external {
        uint256 preBalance=user2balance[msg.sender];
        require(preBalance>=_amount,"amount greater than balance ");
        user2balance[msg.sender]=preBalance-_amount;
        withdrawTo(payable(this),_amount);
        _swapExactETHForTokens(_receiveToken,_amount);  
        emit Withdraw(msg.sender,eth,_amount);
   }
   //swap
    function _swapExactTokensForETH(IERC20 _sendToken,uint256 _amountIn) internal returns(uint256){
            address[] memory path=new address[](2);
            path[0]=address(_sendToken);
            path[1]=eth;
            uint deadline=block.timestamp+300; 
            uint[] memory amounts= router.swapExactTokensForETH(_amountIn,0,path,address(this),deadline);
            return amounts[1];
    }
    function _swapExactETHForTokens(IERC20 _receiveToken,uint256 _amountIn) internal returns(uint256){
            address[] memory path=new address[](2);
            path[0]=eth;
            path[1]=address(_receiveToken);
            uint deadline=block.timestamp+300; 
            uint[] memory amounts=router.swapExactETHForTokens{value : _amountIn}(0,path,msg.sender,deadline);
            return amounts[1];
    }

    /**
      * validate the request:
      * if this is a constructor call, make sure it is a known account.
      * verify the sender has enough tokens.
      * (since the paymaster is also the token, there is no notion of "approval")
      */
    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 /*userOpHash*/, uint256 requiredPreFund)
    internal  override returns (bytes memory context, uint256 validationData) {
        // verificationGasLimit is dual-purposed, as gas limit for postOp. make sure it is high enough
        // make sure that verificationGasLimit is high enough to handle postOp
        require(userOp.verificationGasLimit > COST_OF_POST, "TokenPaymaster: gas too low for postOp");
        address owner= IOwnable(userOp.sender).owner();
        require(user2balance[owner]>=requiredPreFund,"TokenPaymaster: not sufficient funds");
        return (abi.encode(userOp.sender), 0);
    }
    /**
     * actual charge of user.
     * this method will be called just after the user's TX with mode==OpSucceeded|OpReverted (account pays in both cases)
     * BUT: if the user changed its balance in a way that will cause  postOp to revert, then it gets called again, after reverting
     * the user's TX , back to the state it was before the transaction started (before the validatePaymasterUserOp),
     * and the transaction should succeed there.
     */
    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        //we don't really care about the mode, we just pay the gas with the user's tokens.
        (mode);
        address sender = abi.decode(context, (address));
        address owner= IOwnable(sender).owner();
        uint256 charge=actualGasCost + COST_OF_POST;
        uint256 balance=user2balance[owner];
        require(balance>=charge,"not sufficient funds");
        user2balance[owner]=balance-charge;
    }


    fallback() external payable {
        // custom function code
    }

    receive() external payable {
        // custom function code
    }
}
