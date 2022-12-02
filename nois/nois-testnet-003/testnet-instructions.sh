# Create wallet
noisd keys add wallet

## Console output
#- name: wallet
#  type: local
#  address: nois1lfpde6scf7ulzvuq2suavav6cpmpy0rzxne0pw
#  pubkey: '{"@type":"/cosmos.crypto.secp256k1.PubKey","key":"Auq9WzVEs5pCoZgr2WctjI7fU+lJCH0I3r6GC1oa0tc0"}'
#  mnemonic: ""

#!!! SAVE SEED PHRASE (example)
kite upset hip dirt pet winter thunder slice parent flag sand express suffer chest custom pencil mother bargain remember patient other curve cancel sweet

# Wait util the node is synced, should return FALSE
noisd status 2>&1 | jq .SyncInfo.catching_up

# Go to discord channel #testnet-faucet and paste
!request YOUR_WALLET_ADDRESS

# Verify the balance
noisd q bank balances $(noisd keys show wallet -a)

## Console output
#  balances:
#  - amount: "10000000"
#    denom: unois

# Create validator
noisd tx staking create-validator \
--amount=8000000unois \
--pubkey=$(noisd tendermint show-validator) \
--moniker=""YOUR_VALIDATOR_MONIKER"" \
--chain-id=nois-testnet-003 \
--commission-rate=0.1 \
--commission-max-rate=0.2 \
--commission-max-change-rate=0.05 \
--min-self-delegation=1 \
--fees=2000unois \
--from=wallet \
-y

# Make sure you see the validator details
noisd q staking validator $(noisd keys show wallet --bech val -a)