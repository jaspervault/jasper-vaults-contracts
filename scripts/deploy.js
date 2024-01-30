const { ethers, upgrades, run } = require('hardhat');
const network = process.env.HARDHAT_NETWORK
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));
var contractData = {
}
var deployer;
var modules = []

var isVerify=true
async function main() {

    [deployer] = await ethers.getSigners();
    console.log(
        "Deploying contracts with the account:",
        deployer.address
    );
    console.log("Account balance:", (await deployer.getBalance()).toString());

    // await totalMain()

    await _deployFacoty()
    console.log("done balance:", (await deployer.getBalance()).toString());

}

async function totalMain() {

    await _deployDiamond()

    await _deployDiamondData()

    await _deployModule()

    await _deployAdapter()

    await _setAuthority()

    await _bindProtocol();

    fs.writeFileSync(`contractData.${network}.json`, JSON.stringify(contractData));
}



async function _deployFacoty() {
   
    contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));

    var VaultFactory = await deployProxyContract("VaultFactory", true, settings.entryPoint, contractData.Diamond)
    console.log("<VaultFactory>", VaultFactory.address)
    console.log("contractData",contractData)

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
 
    tx = await VaultFactory.setVaultImplementation({ gasLimit: 3800000 })
    console.log(`setVaultImplementation`, tx.hash)
    fs.writeFileSync(`contractData.${network}.json`, JSON.stringify(contractData));
}




async function _bindProtocol() {
    console.log("<<-------bind protocol--------->>")
    var PlatformFacet = await ethers.getContractFactory("PlatformFacet")
    PlatformFacet = PlatformFacet.connect(deployer);
    PlatformFacet = PlatformFacet.attach(contractData.Diamond)
    
    var tx = await PlatformFacet.setProtocols(contractData["TradeModule"], ["UniswapV2ExchangeAdapter", "UniswapV3ExchangeAdapter"], [contractData["UniswapV2ExchangeAdapter"], contractData["UniswapV3ExchangeAdapter"]])
    console.log("trade modules add", tx.hash)
    var tx = await PlatformFacet.setProtocols(contractData["VaultPaymaster"], ["UniswapV2ExchangeAdapter", "UniswapV3ExchangeAdapter"], [contractData["UniswapV2ExchangeAdapter"], contractData["UniswapV3ExchangeAdapter"]])
    console.log("paymaster modules add", tx.hash)
    console.log("<<-------bind protocol done--------->>")
}


async function _setAuthority() {
    console.log("<<------setting platform--------->>")
    var PlatformFacet = await ethers.getContractFactory("PlatformFacet")
    PlatformFacet = PlatformFacet.connect(deployer);
    PlatformFacet = PlatformFacet.attach(contractData.Diamond)

    let _modules = []
    let _modulestatus = []
    for (let i = 0; i < modules.length; i++) {
        _modules.push(modules[i])
        _modulestatus.push(true)
    }
    var tx = await PlatformFacet.setModules(_modules, _modulestatus)
    console.log("add PlatformFact module", tx.hash)

    let _tokens = []
    let _tokenTypes = []
    for (let i = 0; i < settings.tokens.length; i++) {
        _tokens.push(settings.tokens[i].address)
        _tokenTypes.push(settings.tokens[i].type)
    }
    tx = await PlatformFacet.setTokens(_tokens, _tokenTypes);

    tx = await PlatformFacet.setWeth(settings.weth);
    console.log("set weth", tx.hash)
  
    tx = await PlatformFacet.setEth(settings.eth)
    console.log("set eth", tx.hash)

    tx= await PlatformFacet.setAssetTypeCount(settings.positionTypeCount)
    console.log("set assetTypeCount", tx.hash)

    var LendFacet = await ethers.getContractFactory("LendFacet")
    LendFacet = LendFacet.connect(deployer);
    LendFacet = LendFacet.attach(contractData.Diamond)


    tx= await LendFacet.setLendFeePlatformRecipient("0x758dc51d6A6A9BcaE8bdB91587790b9b2239db30")
    console.log("set setLendFeePlatformRecipient", tx.hash)

    var LeverageFacet = await ethers.getContractFactory("LeverageFacet")
    LeverageFacet = LeverageFacet.connect(deployer);
    LeverageFacet = LeverageFacet.attach(contractData.Diamond)

    tx= await LeverageFacet.setleverageLendPlatformFeeRecipient("0x758dc51d6A6A9BcaE8bdB91587790b9b2239db30")
    console.log("set setleverageLendPlatformFeeRecipient", tx.hash)
  
    var Manager = await ethers.getContractFactory("Manager")
    Manager = Manager.connect(deployer);
    Manager = Manager.attach(contractData.Manager)

    tx = await Manager.setDomainHash(settings.name, settings.version, contractData.LendModule)
    console.log("set setDomainHash", tx.hash)

    console.log("<<-------setting platform done--------->>")
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



    var OwnershipFacet = await ethers.getContractFactory("OwnershipFacet")
    OwnershipFacet = OwnershipFacet.connect(deployer);
    OwnershipFacet = OwnershipFacet.attach(contractData.Diamond)
    var tx = await OwnershipFacet.setDBControlWhitelist(protocol, status)
    console.log("add protocol done diamond", tx.hash)
    console.log("<<-------deploy adapter done--------->>")
    console.log("contractData",contractData)
}

async function _deployModule() {
    console.log("<<-------deploy module--------->>")
    var status = []

    var VaultPaymaster = await deployProxyContract("VaultPaymaster", true, contractData.Diamond, settings.entryPoint, 30000)
    console.log("deploy 4337 done")
    modules.push(VaultPaymaster.address)
    status.push(true)

    var VaultManageModule = await deployProxyContract("VaultManageModule", true, contractData.Diamond)
    modules.push(VaultManageModule.address)
    status.push(true)
    console.log("deploy module done")

    var TradeModule = await deployProxyContract("TradeModule", true, contractData.Diamond)
    modules.push(TradeModule.address)
    status.push(true)

    var IssuanceModule = await deployProxyContract("IssuanceModule", true, contractData.Diamond)
    modules.push(IssuanceModule.address)
    status.push(true)


    var Manager = await deployProxyContract("Manager", true, contractData.Diamond)
    modules.push(Manager.address)
    status.push(true)

    console.log("contractData",)
    var LendModule = await deployProxyContract("LendModule", true, contractData.Diamond)
    console.log("deploy LendModule done")
    modules.push(LendModule.address)
    status.push(true)

 
    var LeverageModule=await deployProxyContract("LeverageModule", true, contractData.Diamond)
    modules.push(LeverageModule.address)
    status.push(true)
    console.log("deploy LeverageModule done")

    var OwnershipFacet = await ethers.getContractFactory("OwnershipFacet")
    OwnershipFacet = OwnershipFacet.connect(deployer);
    OwnershipFacet = OwnershipFacet.attach(contractData.Diamond)
    var tx = await OwnershipFacet.setDBControlWhitelist(modules, status)
    console.log("add module done diamond", tx.hash)
    console.log("<<-------deploy module done--------->>")
    console.log("contractData",contractData)
}


async function _deployDiamondData() {
    var DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet")
    DiamondCutFacet = DiamondCutFacet.connect(deployer);
    DiamondCutFacet = DiamondCutFacet.attach(contractData.Diamond)


    var PlatformFacet = await deployContract("PlatformFacet", true)
    var args = getSelectors(PlatformFacet)
    var tx = await DiamondCutFacet.diamondCut(args.diamondCut, args.init, args.calldata)
    console.log(`<contract>:${PlatformFacet.address} add Selector  <hash>:${tx.hash}`)


    var VaultFacet = await deployContract("VaultFacet", true)
    var args = getSelectors(VaultFacet)
    var tx = await DiamondCutFacet.diamondCut(args.diamondCut, args.init, args.calldata)
    console.log(`<contract>:${VaultFacet.address} add Selector  <hash>:${tx.hash}`)



    var PaymasterFacet = await deployContract("PaymasterFacet", true)
    var args = getSelectors(PaymasterFacet)
    var tx = await DiamondCutFacet.diamondCut(args.diamondCut, args.init, args.calldata)
    console.log(`<contract>:${LendFacet.address} add Selector  <hash>:${tx.hash}`)

    var IssuanceFacet=await deployContract("部署IssuanceFacet", true)
    var args = getSelectors(IssuanceFacet)
    var tx = await DiamondCutFacet.diamondCut(args.diamondCut, args.init, args.calldata)
    console.log(`<contract>:${IssuanceFacet.address} add Selector  <hash>:${tx.hash}`)


    var LendFacet = await deployContract("LendFacet", true)
    var args = getSelectors(LendFacet)
    var tx = await DiamondCutFacet.diamondCut(args.diamondCut, args.init, args.calldata)
    console.log(`<contract>:${LendFacet.address} add Selector  <hash>:${tx.hash}`)

    var LeverageFacet=await deployContract("LeverageFacet", true)
    var args = getSelectors(LeverageFacet)
    var tx = await DiamondCutFacet.diamondCut(args.diamondCut, args.init, args.calldata)
    console.log(`<contract>:${LeverageFacet.address} add Selector  <hash>:${tx.hash}`)
    console.log("add diamond data done")
    console.log("contractData",contractData)
}


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
    console.log("contractData",contractData)
}


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

async function deployProxyContract(contractName, verify, ...args) {
    const Contract = await ethers.getContractFactory(contractName);
    var contract = await upgrades.deployProxy(Contract, args);
    console.log("<" + contractName + "> contract address: ", contract.address + " hash: " + contract.deployTransaction.hash);
    contractData[contractName] = contract.address;
    await contract.deployed()
    if (verify && isVerify) {
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

async function upgradeProxyContract(contractName, contractAddress, verify, ...args) {
    const Contract = await ethers.getContractFactory(contractName);
    const contract = await upgrades.upgradeProxy(contractAddress, Contract);
    console.log("<" + contractName + "> contract address: ", contractAddress + " hash: " + contract.hash);
    if (verify && isVerify) {
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
    if (verify && isVerify) {
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
