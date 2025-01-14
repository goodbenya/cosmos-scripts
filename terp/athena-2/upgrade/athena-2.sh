sudo systemctl stop terpd

cd || return
rm -rf terp-core
git clone https://github.com/terpnetwork/terp-core.git
cd terp-core || return
git checkout v0.1.2
make install
terpd version # v0.1.2

terpd config chain-id athena-2
terpd tendermint unsafe-reset-all --home $HOME/.terp

curl -s https://raw.githubusercontent.com/terpnetwork/test-net/master/athena-2/genesis.json > $HOME/.terp/config/genesis.json
sha256sum $HOME/.terp/config/genesis.json # b2acc7ba63b05f5653578b05fc5322920635b35a19691dbafd41ef6374b1bc9a

SEEDS=""
PEERS="15f5bc75be9746fd1f712ca046502cae8a0f6ce7@terp-testnet.nodejumper.io:26656,7e5c0b9384a1b9636f1c670d5dc91ba4721ab1ca@23.88.53.28:36656,14ca69edabb36c51504f1a760292f8e6b9190bd7@65.21.138.123:28656,c989593c89b511318aa6a0c0d361a7a7f4271f28@65.108.124.172:26656,08a0f07da691a2d18d26e35eaa22ec784d1440cd@194.163.164.52:56656"
sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.terp/config/config.toml

sudo systemctl start terpd