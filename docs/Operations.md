# Operations

Common commands for managing roles and permissions in the protocol

## Granting Roles

```bash
source .env.base-sepolia.sh
cat deployments/latest-base-sepolia.json

export ACCESS_MANAGER="0x8406E882415564279f63d2B9Bd824aEb0Cb53cf2"
export FIAT_SETTLEMENT_ROLE=3860893312041324254
export ADDRESS="0x5838b5512cf9f12fe9f2beccb20eb47211f9b0bc" # Backend & Proxy address in Base Sepolia
export ADDRESS="0x6b16d0b334824581b4a24a49fd7fcbd6509ce5da" # Backend & Proxy address in Prod

## Check if the address already has the role
cast call $ACCESS_MANAGER "hasRole(uint64,address)(bool)" $FIAT_SETTLEMENT_ROLE $ADDRESS --rpc-url $RPC_URL

## Grant the role to the address
cast -vvv send $ACCESS_MANAGER "grantRole(uint64,address,uint32)" $FIAT_SETTLEMENT_ROLE $ADDRESS 0 --rpc-url $RPC_URL --mnemonic "$OWNER_MNEMONIC" --mnemonic-index $OWNER_INDEX

```
