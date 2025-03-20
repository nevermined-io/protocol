import { ethers, upgrades } from 'hardhat';

async function main() {
  console.log('Deploying NVMConfig contract for testing...');
  
  // Get signers
  const [owner, governor] = await ethers.getSigners();
  console.log('Owner address:', await owner.getAddress());
  console.log('Governor address:', await governor.getAddress());
  
  // Deploy NVMConfig contract
  const NVMConfig = await ethers.getContractFactory('NVMConfig');
  const nvmConfig = await upgrades.deployProxy(
    NVMConfig,
    [await owner.getAddress(), await governor.getAddress()],
    { initializer: 'initialize' }
  );
  await nvmConfig.waitForDeployment();
  
  const nvmConfigAddress = await nvmConfig.getAddress();
  console.log('NVMConfig deployed to:', nvmConfigAddress);
  console.log('');
  console.log('To test the admin-cli script, run:');
  console.log('export NETWORK=localhost');
  console.log('export MNEMONIC="taxi music thumb unique chat sand crew more leg another off lamp"');
  console.log(`export NVM_CONFIG_ADDRESS=${nvmConfigAddress}`);
  console.log(`npx hardhat run scripts/admin-cli.ts -- check-permissions ${await owner.getAddress()}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
