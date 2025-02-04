#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/common.sh)

printLogo

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="killerqueen-1"
CHAIN_DENOM="uqck"
BINARY_NAME="quicksilverd"
CHEAT_SHEET="https://nodejumper.io/quicksilver-testnet/cheat-sheet"

printLine
echo -e "Node moniker:       ${CYAN}$NODE_MONIKER${NC}"
echo -e "Chain id:           ${CYAN}$CHAIN_ID${NC}"
echo -e "Chain demon:        ${CYAN}$CHAIN_DENOM${NC}"
echo -e "Binary version tag: ${CYAN}$BINARY_VERSION_TAG${NC}"
printLine
sleep 1

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/dependencies_install.sh)

printCyan "4. Building binaries..." && sleep 1

cd || return
rm -rf quicksilver
git clone https://github.com/ingenuity-build/quicksilver.git
cd quicksilver || return
git checkout v0.4.1
make install
quicksilverd version # v0.4.1

quicksilverd config keyring-backend test
quicksilverd config chain-id $CHAIN_ID
quicksilverd init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl https://raw.githubusercontent.com/ingenuity-build/testnets/main/killerqueen/genesis.json > $HOME/.quicksilverd/config/genesis.json
sha256sum $HOME/.quicksilverd/config/genesis.json # 3510dd3310e3a127507a513b3e9c8b24147f549bac013a5130df4b704f1bac75

sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.0001uqck"|g' $HOME/.quicksilverd/config/app.toml
SEEDS="dd3460ec11f78b4a7c4336f22a356fe00805ab64@seed.killerqueen-1.quicksilver.zone:26656,8603d0778bfe0a8d2f8eaa860dcdc5eb85b55982@seed02.killerqueen-1.quicksilver.zone:27676"
PEERS="420ddb75ac0c0eb27d46c41007f18a0bf5588fc0@quicksilver-testnet.nodejumper.io:31656"
sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.quicksilverd/config/config.toml
sed -i 's|^indexer *=.*|indexer = "null"|g' $HOME/.quicksilverd/config/config.toml

# in case of pruning
sed -i 's|pruning = "default"|pruning = "custom"|g' $HOME/.quicksilverd/config/app.toml
sed -i 's|pruning-keep-recent = "0"|pruning-keep-recent = "100"|g' $HOME/.quicksilverd/config/app.toml
sed -i 's|pruning-interval = "0"|pruning-interval = "17"|g' $HOME/.quicksilverd/config/app.toml
sed -i 's|^snapshot-interval *=.*|snapshot-interval = 0|g' $HOME/.quicksilverd/config/app.toml

printCyan "5. Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/quicksilverd.service > /dev/null << EOF
[Unit]
Description=Quicksilver Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which quicksilverd) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

quicksilverd tendermint unsafe-reset-all --home $HOME/.quicksilverd --keep-addr-book

SNAP_RPC="https://quicksilver-testnet.nodejumper.io:443"
LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height); \
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000)); \
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH

sed -i -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" $HOME/.quicksilverd/config/config.toml

sudo systemctl daemon-reload
sudo systemctl enable quicksilverd
sudo systemctl start quicksilverd

printLine
echo -e "Check logs:            ${CYAN}sudo journalctl -u $BINARY_NAME -f --no-hostname -o cat ${NC}"
echo -e "Check synchronization: ${CYAN}$BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up${NC}"
echo -e "More commands:         ${CYAN}$CHEAT_SHEET${NC}"
