export RPC_URL="http://localhost:8545"

export CONTRACTS_DEPLOYMENT_VERSION="1.0.0"
export OWNER_MNEMONIC="test test test test test test test test test test test junk"
export OWNER_INDEX=0
export OWNER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

export GOVERNOR_MNEMONIC="test test test test test test test test test test test junk"
export GOVERNOR_INDEX=1
export GOVERNOR_ADDRESS="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"



# Base Scan
export ETHERSCAN_API_KEY="GG46R7PA464UC7C5T4G6D13ACYVJWJFQ1U"

# Optional configuration
# 1% by default (denominator is 1,000,000)
export NVM_FEE_AMOUNT=10000  
# Fee receiver address (defaults to owner address if not set)
export NVM_FEE_RECEIVER=0x731E7a35DDBB7d2b168D16824B371034f0DD0024

export DEPLOYMENT_ADDRESSES_JSON="./deployments/latest-hardhat.json"

export CONTRACTS_DEPLOYMENT_VERSION=1.0.1
