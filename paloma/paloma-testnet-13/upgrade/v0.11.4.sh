sudo systemctl stop palomad

# upgrade paloma
curl -L https://github.com/palomachain/paloma/releases/download/v0.11.4/paloma_Linux_x86_64.tar.gz > paloma.tar.gz
tar -xvzf paloma.tar.gz
rm -rf paloma.tar.gz
sudo mv -f palomad /usr/local/bin/palomad
palomad version # v0.11.4

sudo systemctl start palomad
