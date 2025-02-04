#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/common.sh)

printLogo

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="altruistic-1"
CHAIN_DENOM="umpwr"
BINARY_NAME="empowerd"
BINARY_VERSION_TAG="v0.0.3"
CHEAT_SHEET="https://nodejumper.io/empower-testnet/cheat-sheet"

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
rm -rf empowerchain
git clone https://github.com/empowerchain/empowerchain
cd empowerchain/chain || return
git checkout v0.0.3
make install
empowerd version # 0.0.3

empowerd config keyring-backend test
empowerd config chain-id $CHAIN_ID
empowerd init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -s https://raw.githubusercontent.com/empowerchain/empowerchain/main/testnets/altruistic-1/genesis.json > $HOME/.empowerchain/config/genesis.json
curl -s https://snapshots2-testnet.nodejumper.io/empower-testnet/addrbook.json > $HOME/.empowerchain/config/addrbook.json

sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.025umpwr"|g' $HOME/.empowerchain/config/app.toml
SEEDS=""
PEERS=""
sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.empowerchain/config/config.toml

PRUNING_INTERVAL=$(shuf -n1 -e 11 13 17 19 23 29 31 37 41 43 47 53 59 61 67 71 73 79 83 89 97)
sed -i 's|^pruning *=.*|pruning = "custom"|g' $HOME/.empowerchain/config/app.toml
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $HOME/.empowerchain/config/app.toml
sed -i 's|^pruning-interval *=.*|pruning-interval = "'$PRUNING_INTERVAL'"|g' $HOME/.empowerchain/config/app.toml
sed -i 's|^snapshot-interval *=.*|snapshot-interval = 2000|g' $HOME/.empowerchain/config/app.toml

sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.025umpwr"|g' $HOME/.empowerchain/config/app.toml
sed -i 's|^prometheus *=.*|prometheus = true|' $HOME/.empowerchain/config/config.toml

printCyan "5. Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/empowerd.service > /dev/null << EOF
[Unit]
Description=Empower Chain Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which empowerd) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

empowerd tendermint unsafe-reset-all --home $HOME/.empowerchain --keep-addr-book

SNAP_NAME=$(curl -s https://snapshots2-testnet.nodejumper.io/empower-testnet/ | egrep -o ">altruistic-1.*\.tar.lz4" | tr -d ">")
curl https://snapshots2-testnet.nodejumper.io/empower-testnet/${SNAP_NAME} | lz4 -dc - | tar -xf - -C $HOME/.empowerchain

sudo systemctl daemon-reload
sudo systemctl enable empowerd
sudo systemctl start empowerd

printLine
echo -e "Check logs:            ${CYAN}sudo journalctl -u $BINARY_NAME -f --no-hostname -o cat ${NC}"
echo -e "Check synchronization: ${CYAN}$BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up${NC}"
echo -e "More commands:         ${CYAN}$CHEAT_SHEET${NC}"