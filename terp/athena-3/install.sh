#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/common.sh)

printLogo

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="athena-3"
CHAIN_DENOM="upersy"
BINARY_NAME="terpd"
BINARY_VERSION_TAG="v0.2.0"
CHEAT_SHEET="https://nodejumper.io/terpnetwork-testnet/cheat-sheet"

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
rm -rf terp-core
git clone https://github.com/terpnetwork/terp-core.git
cd terp-core || return
git checkout v0.2.0
make install
terpd version # 0.2.0

terpd config keyring-backend test
terpd config chain-id $CHAIN_ID
terpd init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -s https://raw.githubusercontent.com/terpnetwork/test-net/master/athena-3/genesis.json > $HOME/.terp/config/genesis.json
curl -s https://snapshots2-testnet.nodejumper.io/terpnetwork-testnet/addrbook.json > $HOME/.terp/config/addrbook.json

SEEDS=""
PEERS=""
sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.terp/config/config.toml

PRUNING_INTERVAL=$(shuf -n1 -e 11 13 17 19 23 29 31 37 41 43 47 53 59 61 67 71 73 79 83 89 97)
sed -i 's|^pruning *=.*|pruning = "custom"|g' $HOME/.terp/config/app.toml
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $HOME/.terp/config/app.toml
sed -i 's|^pruning-interval *=.*|pruning-interval = "'$PRUNING_INTERVAL'"|g' $HOME/.terp/config/app.toml
sed -i 's|^snapshot-interval *=.*|snapshot-interval = 2000|g' $HOME/.terp/config/app.toml

sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.001upersyx"|g' $HOME/.terp/config/app.toml
sed -i 's|^prometheus *=.*|prometheus = true|' $HOME/.terp/config/config.toml

printCyan "5. Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/terpd.service > /dev/null << EOF
[Unit]
Description=TerpNetwork Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which terpd) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

terpd tendermint unsafe-reset-all --home $HOME/.terp --keep-addr-book

SNAP_NAME=$(curl -s https://snapshots2-testnet.nodejumper.io/terpnetwork-testnet/ | egrep -o ">athena-3.*\.tar.lz4" | tr -d ">")
curl https://snapshots2-testnet.nodejumper.io/terpnetwork-testnet/${SNAP_NAME} | lz4 -dc - | tar -xf - -C $HOME/.terp

sudo systemctl daemon-reload
sudo systemctl enable terpd
sudo systemctl start terpd

printLine
echo -e "Check logs:            ${CYAN}sudo journalctl -u $BINARY_NAME -f --no-hostname -o cat ${NC}"
echo -e "Check synchronization: ${CYAN}$BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up${NC}"
echo -e "More commands:         ${CYAN}$CHEAT_SHEET${NC}"
