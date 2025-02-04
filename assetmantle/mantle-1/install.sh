#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/common.sh)

printLogo

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="mantle-1"
CHAIN_DENOM="umntl"
BINARY_NAME="mantleNode"
BINARY_VERSION_TAG="v0.3.0"
CHEAT_SHEET="https://nodejumper.io/assetmantle/cheat-sheet"

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
rm -rf node
git clone https://github.com/AssetMantle/node.git
cd node || return
git checkout v0.3.0
make install
mantleNode version # HEAD-5b2b0dcb37b107b0e0c1eaf9e907aa9f1a1992d9

mantleNode config chain-id $CHAIN_ID
mantleNode init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -s https://raw.githubusercontent.com/AssetMantle/genesisTransactions/main/mantle-1/final_genesis.json > $HOME/.mantleNode/config/genesis.json
# TODO: add addresbbok
# curl -s https://snapshots2.nodejumper.io/jackal/addrbook.json > $HOME/.mantleNode/config/addrbook.json

SEEDS="10de5165a61dd83c768781d438748c14e11f4397@seed.assetmantle.one:26656"
PEERS=""
sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.mantleNode/config/config.toml

PRUNING_INTERVAL=$(shuf -n1 -e 11 13 17 19 23 29 31 37 41 43 47 53 59 61 67 71 73 79 83 89 97)
sed -i 's|^pruning *=.*|pruning = "custom"|g' $HOME/.mantleNode/config/app.toml
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $HOME/.mantleNode/config/app.toml
sed -i 's|^pruning-interval *=.*|pruning-interval = "'$PRUNING_INTERVAL'"|g' $HOME/.mantleNode/config/app.toml

sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.001umntl"|g' $HOME/.mantleNode/config/app.toml
sed -i 's|^prometheus *=.*|prometheus = true|' $HOME/.mantleNode/config/config.toml

printCyan "5. Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/mantleNode.service > /dev/null << EOF
[Unit]
Description=AssetMantle Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which mantleNode) start --x-crisis-skip-assert-invariants
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# TODO: enable sync block
# mantleNode tendermint unsafe-reset-all --home $HOME/.mantleNode --keep-addr-book
#
#SNAP_RPC="https://jackal.nodejumper.io:443"
#
#LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height)
#BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000))
#TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)
#
#echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH
#
#sed -i 's|^enable *=.*|enable = true|' $HOME/.mantleNode/config/config.toml
#sed -i 's|^rpc_servers *=.*|rpc_servers = "'$SNAP_RPC,$SNAP_RPC'"|' $HOME/.mantleNode/config/config.toml
#sed -i 's|^trust_height *=.*|trust_height = '$BLOCK_HEIGHT'|' $HOME/.mantleNode/config/config.toml
#sed -i 's|^trust_hash *=.*|trust_hash = "'$TRUST_HASH'"|' $HOME/.mantleNode/config/config.toml

sudo systemctl daemon-reload
sudo systemctl enable mantleNode
sudo systemctl start mantleNode

printLine
echo -e "Check logs:            ${CYAN}sudo journalctl -u $BINARY_NAME -f --no-hostname -o cat ${NC}"
echo -e "Check synchronization: ${CYAN}$BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up${NC}"
echo -e "More commands:         ${CYAN}$CHEAT_SHEET${NC}"
