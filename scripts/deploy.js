const { ethers, upgrades, run } = require('hardhat');
const network = process.env.HARDHAT_NETWORK
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));
var contractData = {

}
var deployer;
var modules = []
async function main() {
    //先部署钻石合约
    [deployer] = await ethers.getSigners();
    console.log(
        "Deploying contracts with the account:",
        deployer.address
    );
    console.log("Account balance:", (await deployer.getBalance()).toString());
    //部署合约
    await totalMain()
    //部署factory
    // await _deployFacoty()
    console.log("done balance:", (await deployer.getBalance()).toString());

}

async function totalMain() {
    //部署2535合约
    await _deployDiamond()
    //添加函数选择器
    await _deployDiamondData()
    //部署module
    await _deployModule()
    //部署adapter
    await _deployAdapter()
    //配置平台相关
    await _setAuthority()
    //绑定平台和协议之间的关系
    await _bindProtocol();
    //写入文件
    fs.writeFileSync(`contractData.${network}.json`, JSON.stringify(contractData));
}



async function _deployFacoty() {
    //获取合约数据  
    contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
    // 部署VaultFactory
    var VaultFactory = await deployProxyContract("VaultFactory", true, settings.entryPoint, contractData.Diamond)
    console.log("<VaultFactory>", VaultFactory.address)
    //添加factory 到diamond
    var OwnershipFacet = await ethers.getContractFactory("OwnershipFacet")
    OwnershipFacet = OwnershipFacet.connect(deployer);
    OwnershipFacet = OwnershipFacet.attach(contractData.Diamond)
    var tx = await OwnershipFacet.setDBControlWhitelist([VaultFactory.address], [true])
    console.log(`add VaultFactory done`, tx.hash)

    var PlatformFacet = await ethers.getContractFactory("PlatformFacet")
    PlatformFacet = PlatformFacet.connect(deployer);
    PlatformFacet = PlatformFacet.attach(contractData.Diamond)
    tx = await PlatformFacet.setModules([VaultFactory.address], [true])
    console.log(`add VaultFactory done2`, tx.hash)

    //添加实例化对象
    tx = await VaultFactory.setVaultImplementation({ gasLimit: 1800000 })
    console.log(`setVaultImplementation`, tx.hash)

    fs.writeFileSync(`contractData.${network}.json`, JSON.stringify(contractData));
}

async function _deployModule() {
    console.log("<<-------deploy module--------->>")
    var status = []
    //部署VaultPaymater
    var VaultPaymaster = await deployProxyContract("VaultPaymaster", true, contractData.Diamond, settings.entryPoint, 30000)
    console.log("deploy 4337 done")
    modules.push(VaultPaymaster.address)
    status.push(true)
    // 部署VaultManageModule 
    var VaultManageModule = await deployProxyContract("VaultManageModule", true, contractData.Diamond)
    modules.push(VaultManageModule.address)
    status.push(true)
    console.log("deploy module done")
    //部署tradeModule
    var TradeModule = await deployProxyContract("TradeModule", true, contractData.Diamond)
    modules.push(TradeModule.address)
    status.push(true)
    //部署IssuanceModule
    var IssuanceModule = await deployProxyContract("IssuanceModule", true, contractData.Diamond)
    modules.push(IssuanceModule.address)
    status.push(true)

    //部署Manager
    var Manager = await deployProxyContract("Manager", true, contractData.Diamond)
    modules.push(Manager.address)
    status.push(true)
    //部署 LendModule
    console.log("contractData",)
    var LendModule = await deployProxyContract("LendModule", true, contractData.Diamond)
    console.log("deploy LendModule done")
    modules.push(LendModule.address)
    status.push(true)

    //添加进入modules(diamond))  diamond访问白名单
    var OwnershipFacet = await ethers.getContractFactory("OwnershipFacet")
    OwnershipFacet = OwnershipFacet.connect(deployer);
    OwnershipFacet = OwnershipFacet.attach(contractData.Diamond)
    var tx = await OwnershipFacet.setDBControlWhitelist(modules, status)
    console.log("add module done diamond", tx.hash)
    console.log("<<-------deploy module done--------->>")
}

async function _deployAdapter() {
    let protocol = []
    let status = []
    console.log("<<-------deploy adapter--------->>")
    var UniswapV2ExchangeAdapter = await deployProxyContract("UniswapV2ExchangeAdapter", true, contractData.Diamond, settings.uniswapRouterV2)
    protocol.push(UniswapV2ExchangeAdapter.address)
    status.push(true)
    var UniswapV3ExchangeAdapter = await deployProxyContract("UniswapV3ExchangeAdapter", true, contractData.Diamond, settings.uniswapRouterV3)
    protocol.push(UniswapV3ExchangeAdapter.address)
    status.push(true)


    //添加进入protocol(diamond))  diamond访问白名单
    var OwnershipFacet = await ethers.getContractFactory("OwnershipFacet")
    OwnershipFacet = OwnershipFacet.connect(deployer);
    OwnershipFacet = OwnershipFacet.attach(contractData.Diamond)
    var tx = await OwnershipFacet.setDBControlWhitelist(protocol, status)
    console.log("add protocol done diamond", tx.hash)
    console.log("<<-------deploy adapter done--------->>")
}

//设置模块  协议  代币
async function _setAuthority() {
    console.log("<<------setting platform--------->>")
    var PlatformFacet = await ethers.getContractFactory("PlatformFacet")
    PlatformFacet = PlatformFacet.connect(deployer);
    PlatformFacet = PlatformFacet.attach(contractData.Diamond)
    //添加module
    let _modules = []
    let _modulestatus = []
    for (let i = 0; i < modules.length; i++) {
        _modules.push(modules[i])
        _modulestatus.push(true)
    }
    var tx = await PlatformFacet.setModules(_modules, _modulestatus)
    console.log("add PlatformFact module", tx.hash)
    //添加代币
    let _tokens = []
    let _tokenTypes = []
    for (let i = 0; i < settings.tokens.length; i++) {
        _tokens.push(settings.tokens[i].address)
        _tokenTypes.push(settings.tokens[i].type)
    }
    tx = await PlatformFacet.setTokens(_tokens, _tokenTypes);



    //设置weth
    tx = await PlatformFacet.setWeth(settings.weth);
    console.log("set weth", tx.hash)
    //设置eth
    tx = await PlatformFacet.setEth(settings.eth)
    console.log("set eth", tx.hash)

    //设置lendModule
    var LendModule = await ethers.getContractFactory("LendModule")
    LendModule = LendModule.connect(deployer);
    LendModule = LendModule.attach(contractData.LendModule)

    tx = await LendModule.setDomainHash(settings.name, settings.version, contractData.LendModule)
    console.log("set setDomainHash", tx.hash)

    tx = await LendModule.setLendFeePlatformRecipient(deployer.address)
    console.log("set setLendFeePlatformRecipient", tx.hash)
    console.log("<<-------setting platform done--------->>")
}

//绑定协议
async function _bindProtocol() {
    console.log("<<-------bind protocol--------->>")
    var PlatformFacet = await ethers.getContractFactory("PlatformFacet")
    PlatformFacet = PlatformFacet.connect(deployer);
    PlatformFacet = PlatformFacet.attach(contractData.Diamond)
    //绑定tradeModule相关    
    var tx = await PlatformFacet.setProtocols(contractData["TradeModule"], ["UniswapV2ExchangeAdapter", "UniswapV3ExchangeAdapter"], [contractData["UniswapV2ExchangeAdapter"], contractData["UniswapV3ExchangeAdapter"]])
    console.log("trade modules add", tx.hash)
    var tx = await PlatformFacet.setProtocols(contractData["VaultPaymaster"], ["UniswapV2ExchangeAdapter", "UniswapV3ExchangeAdapter"], [contractData["UniswapV2ExchangeAdapter"], contractData["UniswapV3ExchangeAdapter"]])
    console.log("paymaster modules add", tx.hash)
    console.log("<<-------bind protocol done--------->>")
}


//部署砖石合约
async function _deployDiamond() {
    var DiamondCutFacet = await deployContract("DiamondCutFacet", true)
    var DiamondLoupeFacet = await deployContract("DiamondLoupeFacet", true)
    var OwnershipFacet = await deployContract("OwnershipFacet", true)
    let calldata = OwnershipFacet.interface.encodeFunctionData('setDBControlWhitelist', [[OwnershipFacet.address], [true]])
    var diamondArgs = {
        owner: deployer.address,
        init: OwnershipFacet.address,
        initCalldata: calldata
    }
    var diamondFacets = []
    var diamondCutSelectors = getSelectors(DiamondCutFacet)
    var diamondLoupeSelectors = getSelectors(DiamondLoupeFacet)
    var ownershipSelectors = getSelectors(OwnershipFacet)
    diamondFacets.push(...diamondCutSelectors.diamondCut)
    diamondFacets.push(...diamondLoupeSelectors.diamondCut)
    diamondFacets.push(...ownershipSelectors.diamondCut)
    var Diamond = await deployContract("Diamond", true, diamondFacets, diamondArgs)
    console.log("deploy diamond  done")
}

async function _deployDiamondData() {
    var DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet")
    DiamondCutFacet = DiamondCutFacet.connect(deployer);
    DiamondCutFacet = DiamondCutFacet.attach(contractData.Diamond)

    //部署相关数据合约
    //部署Platform数据  PlatformFacet
    var PlatformFacet = await deployContract("PlatformFacet", true)
    var args = getSelectors(PlatformFacet)
    var tx = await DiamondCutFacet.diamondCut(args.diamondCut, args.init, args.calldata)
    console.log(`<contract>:${PlatformFacet.address} add Selector  <hash>:${tx.hash}`)
    //部署vault数据 VaultFacet

    var VaultFacet = await deployContract("VaultFacet", true)
    var args = getSelectors(VaultFacet)
    var tx = await DiamondCutFacet.diamondCut(args.diamondCut, args.init, args.calldata)
    console.log(`<contract>:${VaultFacet.address} add Selector  <hash>:${tx.hash}`)

    //部署LendFacet 
    var LendFacet = await deployContract("LendFacet", true)
    var args = getSelectors(LendFacet)
    var tx = await DiamondCutFacet.diamondCut(args.diamondCut, args.init, args.calldata)
    console.log(`<contract>:${LendFacet.address} add Selector  <hash>:${tx.hash}`)
    //部署PaymasterFacet
    var PaymasterFacet = await deployContract("PaymasterFacet", true)
    var args = getSelectors(PaymasterFacet)
    var tx = await DiamondCutFacet.diamondCut(args.diamondCut, args.init, args.calldata)
    console.log(`<contract>:${LendFacet.address} add Selector  <hash>:${tx.hash}`)
    console.log("add diamond data done")
}

//获取函数选择器
function getSelectors(contract) {
    var signatures = Object.keys(contract.interface.functions)
    var selectors = signatures.reduce((acc, val) => {
        if (val !== 'init(bytes)') {
            // console.log(`${contract.interface.getSighash(val)}-->${val}`)
            acc.push(contract.interface.getSighash(val))
        }
        return acc
    }, [])
    // let calldata = contract.interface.encodeFunctionData('setModules',[[contract.address],[true]])
    // console.log("calldata",calldata)
    let args = {
        diamondCut: [{
            facetAddress: contract.address,
            addSelectors: selectors,
            removeSelectors: []
        }],
        init: ethers.constants.AddressZero,
        calldata: "0x"
    }
    return args
}
//部署合约(uups)
async function deployProxyContract(contractName, verify, ...args) {
    const Contract = await ethers.getContractFactory(contractName);
    var contract = await upgrades.deployProxy(Contract, args);
    console.log("<" + contractName + "> contract address: ", contract.address + " hash: " + contract.deployTransaction.hash);
    contractData[contractName] = contract.address;
    await contract.deployed()
    if (verify) {
        var r = await contract.deployTransaction.wait(settings.safeBlock);
        try {
            await run("verify:verify", {
                address: contract.address,
                // constructorArguments: args,
            });
            console.log("verified contract <" + contractName + "> address:", contract.address);
        } catch (error) {
            console.log(error.message);
            return contract;
        }
    }
    else {
        var r = await contract.deployTransaction.wait(1);
    }
    return contract;
}
//升级合约(uups)
async function upgradeProxyContract(contractName, contractAddress, verify, ...args) {
    const Contract = await ethers.getContractFactory(contractName);
    const contract = await upgrades.upgradeProxy(contractAddress, Contract);
    console.log("<" + contractName + "> contract address: ", contractAddress + " hash: " + contract.hash);
    if (verify) {
        var r = await contract.wait(settings.safeBlock);
        try {
            await run("verify:verify", {
                address: contractAddress,
                constructorArguments: args,
            });
            console.log("verified contract <" + contractName + "> address:", contractAddress);
        } catch (error) {
            console.log(error.message);
        }
    }
    else {
        var r = await contract.wait(1);
    }
}

async function deployContract(contractName, verify, ...args) {
    const Contract = await ethers.getContractFactory(contractName);
    var contract = await Contract.deploy(...args);
    console.log("<" + contractName + "> contract address: ", contract.address + " hash: " + contract.deployTransaction.hash);
    contractData[contractName] = contract.address;
    await contract.deployed()
    if (verify) {
        var r = await contract.deployTransaction.wait(settings.safeBlock);
        try {
            await run("verify:verify", {
                address: contract.address,
                constructorArguments: args,
            });
            console.log("verified contract <" + contractName + "> address:", contract.address);
        } catch (error) {
            console.log(error.message);
            return contract;
        }
    }
    else {
        var r = await contract.deployTransaction.wait(1);
    }
    return contract;
}



main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
