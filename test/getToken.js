const { ethers } = require("hardhat");
const fs = require('fs');
const network = process.argv[process.argv.length-1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));

describe("getToken",function(){

    var deployer;
    var WETH9;

    var UniswapRouter;



    before(async function(){

        [deployer]=await ethers.getSigners();

          let abiWeth=[
            {
              "inputs": [],
              "name": "deposit",
              "outputs": [],
              "stateMutability": "payable",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "address",
                  "name": "dst",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "wad",
                  "type": "uint256"
                }
              ],
              "name": "transfer",
              "outputs": [
                {
                  "internalType": "bool",
                  "name": "",
                  "type": "bool"
                }
              ],
              "stateMutability": "nonpayable",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "uint256",
                  "name": "wad",
                  "type": "uint256"
                }
              ],
              "name": "withdraw",
              "outputs": [],
              "stateMutability": "nonpayable",
              "type": "function"
            }
          ]
          WETH9=await  new ethers.Contract("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", abiWeth, deployer)


          let abiUniswapRouter=[
            {
              "inputs": [],
              "name": "WETH",
              "outputs": [
                {
                  "internalType": "address",
                  "name": "",
                  "type": "address"
                }
              ],
              "stateMutability": "pure",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "address",
                  "name": "tokenA",
                  "type": "address"
                },
                {
                  "internalType": "address",
                  "name": "tokenB",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "amountADesired",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountBDesired",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountAMin",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountBMin",
                  "type": "uint256"
                },
                {
                  "internalType": "address",
                  "name": "to",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "deadline",
                  "type": "uint256"
                }
              ],
              "name": "addLiquidity",
              "outputs": [
                {
                  "internalType": "uint256",
                  "name": "amountA",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountB",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "liquidity",
                  "type": "uint256"
                }
              ],
              "stateMutability": "nonpayable",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "address",
                  "name": "token",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "amountTokenDesired",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountTokenMin",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountETHMin",
                  "type": "uint256"
                },
                {
                  "internalType": "address",
                  "name": "to",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "deadline",
                  "type": "uint256"
                }
              ],
              "name": "addLiquidityETH",
              "outputs": [
                {
                  "internalType": "uint256",
                  "name": "amountToken",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountETH",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "liquidity",
                  "type": "uint256"
                }
              ],
              "stateMutability": "payable",
              "type": "function"
            },
            {
              "inputs": [],
              "name": "factory",
              "outputs": [
                {
                  "internalType": "address",
                  "name": "",
                  "type": "address"
                }
              ],
              "stateMutability": "pure",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "uint256",
                  "name": "amountOut",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "reserveIn",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "reserveOut",
                  "type": "uint256"
                }
              ],
              "name": "getAmountIn",
              "outputs": [
                {
                  "internalType": "uint256",
                  "name": "amountIn",
                  "type": "uint256"
                }
              ],
              "stateMutability": "pure",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "uint256",
                  "name": "amountIn",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "reserveIn",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "reserveOut",
                  "type": "uint256"
                }
              ],
              "name": "getAmountOut",
              "outputs": [
                {
                  "internalType": "uint256",
                  "name": "amountOut",
                  "type": "uint256"
                }
              ],
              "stateMutability": "pure",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "uint256",
                  "name": "amountOut",
                  "type": "uint256"
                },
                {
                  "internalType": "address[]",
                  "name": "path",
                  "type": "address[]"
                }
              ],
              "name": "getAmountsIn",
              "outputs": [
                {
                  "internalType": "uint256[]",
                  "name": "amounts",
                  "type": "uint256[]"
                }
              ],
              "stateMutability": "view",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "uint256",
                  "name": "amountIn",
                  "type": "uint256"
                },
                {
                  "internalType": "address[]",
                  "name": "path",
                  "type": "address[]"
                }
              ],
              "name": "getAmountsOut",
              "outputs": [
                {
                  "internalType": "uint256[]",
                  "name": "amounts",
                  "type": "uint256[]"
                }
              ],
              "stateMutability": "view",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "uint256",
                  "name": "amountA",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "reserveA",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "reserveB",
                  "type": "uint256"
                }
              ],
              "name": "quote",
              "outputs": [
                {
                  "internalType": "uint256",
                  "name": "amountB",
                  "type": "uint256"
                }
              ],
              "stateMutability": "pure",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "address",
                  "name": "tokenA",
                  "type": "address"
                },
                {
                  "internalType": "address",
                  "name": "tokenB",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "liquidity",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountAMin",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountBMin",
                  "type": "uint256"
                },
                {
                  "internalType": "address",
                  "name": "to",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "deadline",
                  "type": "uint256"
                }
              ],
              "name": "removeLiquidity",
              "outputs": [
                {
                  "internalType": "uint256",
                  "name": "amountA",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountB",
                  "type": "uint256"
                }
              ],
              "stateMutability": "nonpayable",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "address",
                  "name": "token",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "liquidity",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountTokenMin",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountETHMin",
                  "type": "uint256"
                },
                {
                  "internalType": "address",
                  "name": "to",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "deadline",
                  "type": "uint256"
                }
              ],
              "name": "removeLiquidityETH",
              "outputs": [
                {
                  "internalType": "uint256",
                  "name": "amountToken",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountETH",
                  "type": "uint256"
                }
              ],
              "stateMutability": "nonpayable",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "address",
                  "name": "token",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "liquidity",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountTokenMin",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountETHMin",
                  "type": "uint256"
                },
                {
                  "internalType": "address",
                  "name": "to",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "deadline",
                  "type": "uint256"
                },
                {
                  "internalType": "bool",
                  "name": "approveMax",
                  "type": "bool"
                },
                {
                  "internalType": "uint8",
                  "name": "v",
                  "type": "uint8"
                },
                {
                  "internalType": "bytes32",
                  "name": "r",
                  "type": "bytes32"
                },
                {
                  "internalType": "bytes32",
                  "name": "s",
                  "type": "bytes32"
                }
              ],
              "name": "removeLiquidityETHWithPermit",
              "outputs": [
                {
                  "internalType": "uint256",
                  "name": "amountToken",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountETH",
                  "type": "uint256"
                }
              ],
              "stateMutability": "nonpayable",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "address",
                  "name": "tokenA",
                  "type": "address"
                },
                {
                  "internalType": "address",
                  "name": "tokenB",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "liquidity",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountAMin",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountBMin",
                  "type": "uint256"
                },
                {
                  "internalType": "address",
                  "name": "to",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "deadline",
                  "type": "uint256"
                },
                {
                  "internalType": "bool",
                  "name": "approveMax",
                  "type": "bool"
                },
                {
                  "internalType": "uint8",
                  "name": "v",
                  "type": "uint8"
                },
                {
                  "internalType": "bytes32",
                  "name": "r",
                  "type": "bytes32"
                },
                {
                  "internalType": "bytes32",
                  "name": "s",
                  "type": "bytes32"
                }
              ],
              "name": "removeLiquidityWithPermit",
              "outputs": [
                {
                  "internalType": "uint256",
                  "name": "amountA",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountB",
                  "type": "uint256"
                }
              ],
              "stateMutability": "nonpayable",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "uint256",
                  "name": "amountOut",
                  "type": "uint256"
                },
                {
                  "internalType": "address[]",
                  "name": "path",
                  "type": "address[]"
                },
                {
                  "internalType": "address",
                  "name": "to",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "deadline",
                  "type": "uint256"
                }
              ],
              "name": "swapETHForExactTokens",
              "outputs": [
                {
                  "internalType": "uint256[]",
                  "name": "amounts",
                  "type": "uint256[]"
                }
              ],
              "stateMutability": "payable",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "uint256",
                  "name": "amountOutMin",
                  "type": "uint256"
                },
                {
                  "internalType": "address[]",
                  "name": "path",
                  "type": "address[]"
                },
                {
                  "internalType": "address",
                  "name": "to",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "deadline",
                  "type": "uint256"
                }
              ],
              "name": "swapExactETHForTokens",
              "outputs": [
                {
                  "internalType": "uint256[]",
                  "name": "amounts",
                  "type": "uint256[]"
                }
              ],
              "stateMutability": "payable",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "uint256",
                  "name": "amountIn",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountOutMin",
                  "type": "uint256"
                },
                {
                  "internalType": "address[]",
                  "name": "path",
                  "type": "address[]"
                },
                {
                  "internalType": "address",
                  "name": "to",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "deadline",
                  "type": "uint256"
                }
              ],
              "name": "swapExactTokensForETH",
              "outputs": [
                {
                  "internalType": "uint256[]",
                  "name": "amounts",
                  "type": "uint256[]"
                }
              ],
              "stateMutability": "nonpayable",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "uint256",
                  "name": "amountIn",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountOutMin",
                  "type": "uint256"
                },
                {
                  "internalType": "address[]",
                  "name": "path",
                  "type": "address[]"
                },
                {
                  "internalType": "address",
                  "name": "to",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "deadline",
                  "type": "uint256"
                }
              ],
              "name": "swapExactTokensForTokens",
              "outputs": [
                {
                  "internalType": "uint256[]",
                  "name": "amounts",
                  "type": "uint256[]"
                }
              ],
              "stateMutability": "nonpayable",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "uint256",
                  "name": "amountOut",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountInMax",
                  "type": "uint256"
                },
                {
                  "internalType": "address[]",
                  "name": "path",
                  "type": "address[]"
                },
                {
                  "internalType": "address",
                  "name": "to",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "deadline",
                  "type": "uint256"
                }
              ],
              "name": "swapTokensForExactETH",
              "outputs": [
                {
                  "internalType": "uint256[]",
                  "name": "amounts",
                  "type": "uint256[]"
                }
              ],
              "stateMutability": "nonpayable",
              "type": "function"
            },
            {
              "inputs": [
                {
                  "internalType": "uint256",
                  "name": "amountOut",
                  "type": "uint256"
                },
                {
                  "internalType": "uint256",
                  "name": "amountInMax",
                  "type": "uint256"
                },
                {
                  "internalType": "address[]",
                  "name": "path",
                  "type": "address[]"
                },
                {
                  "internalType": "address",
                  "name": "to",
                  "type": "address"
                },
                {
                  "internalType": "uint256",
                  "name": "deadline",
                  "type": "uint256"
                }
              ],
              "name": "swapTokensForExactTokens",
              "outputs": [
                {
                  "internalType": "uint256[]",
                  "name": "amounts",
                  "type": "uint256[]"
                }
              ],
              "stateMutability": "nonpayable",
              "type": "function"
            }
          ]
          UniswapRouter =await  new ethers.Contract("0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",abiUniswapRouter,deployer)
    })
    it.skip("getWeth",async function(){
       let res=   await  WETH9.deposit({value:String(10**20)})
       console.log(res,"--")
    })

    it.only("eth to Usdc",async function(){
       let usdc="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
       let weth="0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
       let wbtc="0x2260fac5e5542a773aa44fbcfedf7c193bc2c599"
       let path=[weth,wbtc]
       let date=parseInt(new Date().getTime()/1000 +36000)
       console.log(deployer.address,"---")
       //uint amountOutMin, address[] calldata path, address to, uint deadline
       var res= await UniswapRouter.swapExactETHForTokens(4000,path,"0x3240622cb8480Cc0F9D9482D3b2EFF5916bde496",date,{value:String(200*10**18)})
       console.log(res)
    }).timeout(100000000000)
  
})