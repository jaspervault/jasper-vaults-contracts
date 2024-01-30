
const { ethers,upgrades,run } = require('hardhat');
const network = process.env.HARDHAT_NETWORK
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));

var contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
var deployer;
async function main() {
  [deployer]=await ethers.getSigners();
  var contract=contractData.VaultFacet
  await deleteSelector(contract)
}

async  function deleteSelector(_facetAddress){
        var Contract= await  getDeployedContract("Manager",contractData.Manager)
        var tx= await Contract.deleteFacetAllSelector(_facetAddress,{gasLimit:5000000})
        console.log(`<contract>:${_facetAddress} delete Selector  <hash>:${tx.hash}`)
        await tx.wait(1)
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
