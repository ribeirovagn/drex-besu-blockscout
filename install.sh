#!/bin/bash

rm -fr ./config ./bootnode ./node* ./data
# sudo rm -fr $PWD/blockscout-5.4.0-beta/docker-compose/services/logs/
# sudo rm -fr $PWD/blockscout-5.4.0-beta/docker-compose/services/blockscout-db-data/
# sudo rm -fr $PWD/blockscout-5.4.0-beta/docker-compose/services/redis-data/
# sudo rm -fr $PWD/blockscout-5.4.0-beta/docker-compose/services/stats-db-data/

mkdir ./config
mkdir -p ./data

nodes=3

cat > qbftConfigFile.json << EOF
{
    "genesis": {
        "config": {
            "chainId": 1217,
            "muirglacierblock": 0,
            "londonBlock": 2592800,
            "zeroBaseFee": true,
            "qbft": {
                "blockperiodseconds": 5,
                "epochlength": 30000,
                "requesttimeoutseconds": 10
            }
        },
        "nonce": "0x0",
        "timestamp": "0x58ee40ba",
        "gasLimit": "0x1fffffffffffff",
        "difficulty": "0x1",
        "mixHash": "0x63746963616c2062797a616e74696e65206661756c7420746f6c6572616e6365",
        "coinbase": "0x0000000000000000000000000000000000000000",
        "alloc": {
            "fe3b557e8fb62b89f4916b721be55ceb828dbd73": {
                "privateKey": "8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63",
                "comment": "This is Alice's Key. Private key and this comment are ignored.  In a real chain, the private key should NOT be stored",
                "balance": "80000000000000000000000"
              },
              "627306090abaB3A6e1400e9345bC60c78a8BEf57": {
                "privateKey": "c87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3",
                "comment": "This is the contract's Key. Private key and this comment are ignored.  In a real chain, the private key should NOT be stored",
                "balance": "70000000000000000000000"
              },
              "f17f52151EbEF6C7334FAD080c5704D77216b732": {
                "privateKey": "ae6ae8e5ccbfb04590405997ee2d52d2b330726137b875053c36d94e974d162f",
                "comment": "This is Bob's Key. Private key and this comment are ignored.  In a real chain, the private key should NOT be stored",
                "balance": "90000000000000000000000"
              }
        }
    },
    "blockchain": {
        "nodes": {
            "generate": true,
            "count": $(($nodes+1))
        }
    }
}
EOF

cp qbftConfigFile.json ./config

docker run \
-v $PWD/config:/opt/besu/config \
-v $PWD/data:/opt/besu/data \
hyperledger/besu:latest operator generate-blockchain-config \
--config-file=/opt/besu/config/qbftConfigFile.json \
--to=/opt/besu/data \
--private-key-file-name=key

rm ./config/qbftConfigFile.json
mv ./data/genesis.json ./config
keyFolder=$(ls $PWD/data/keys | head -n 1)
mkdir -p bootnode/data
bootnode_id=$(cat $PWD/data/keys/$keyFolder/key.pub | sed 's/^0x//')
echo $bootnode_id > ./config/bootnode_id
mv $PWD/data/keys/$keyFolder/* $PWD/bootnode/data
rm -fr $PWD/data/keys/$keyFolder

cat > docker-compose.yaml << EOF
version: "3.0"
networks:
  cdbc-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.16.240.0/24
services:
  bootnode:
    image: hyperledger/besu:latest
    restart: unless-stopped
    container_name: bootnode
    command: 
      --identity=bootnode
      --data-path=/opt/besu/data
      --genesis-file=/opt/besu/genesis.json
      --min-gas-price=0
      --host-allowlist=*
      --rpc-http-enabled
      --rpc-http-api=ADMIN,DEBUG,ETH,NET,PERM,PLUGINS,QBFT,TRACE,TXPOOL,WEB3
      --rpc-http-cors-origins=all
      --rpc-ws-enabled
      --rpc-ws-api=ADMIN,DEBUG,ETH,NET,PERM,PLUGINS,QBFT,TRACE,TXPOOL,WEB3
      --rpc-ws-host=0.0.0.0
      --rpc-ws-max-active-connections=100
      --rpc-ws-port=8546
    volumes:
      - ./bootnode/data:/opt/besu/data
      - ./config/genesis.json:/opt/besu/genesis.json
    ports:
      - "8545:8545"
      - "30303:30303"
      - "8546:8546"
    networks:
      cdbc-network:
        ipv4_address: 172.16.240.30
EOF


for((i=1; i<=nodes; i++)) do 
    keyFolder=$(ls $PWD/data/keys | head -n 1)
    mkdir -p node$i/data
    mv $PWD/data/keys/$keyFolder/* ./node$i/data
    rm -fr $PWD/data/keys/$keyFolder

cat >> docker-compose.yaml << EOF
  node$i:
    image: hyperledger/besu:latest
    restart: unless-stopped
    container_name: node$i
    command: 
      --identity=node$i
      --data-path=/opt/besu/data
      --genesis-file=/opt/besu/genesis.json
      --min-gas-price=0
      --bootnodes=enode://$bootnode_id@172.16.240.30:30303
      --p2p-port=30303
    volumes:
      - ./node$i/data:/opt/besu/data
      - ./config/genesis.json:/opt/besu/genesis.json
    depends_on:
      - bootnode      
    networks:
      cdbc-network:
        ipv4_address: 172.16.240.$((30+i))
EOF

echo node$i ok
done
cat >> docker-compose.yaml << EOF

  redis_db:
    extends:
      file: ./blockscout-5.4.0-beta/docker-compose/services/redis.yml
      service: redis_db

  db-init:
    extends:
      file: ./blockscout-5.4.0-beta/docker-compose/services/db.yml
      service: db-init
    depends_on:
      - bootnode      

  db:
    extends:
      file: ./blockscout-5.4.0-beta/docker-compose/services/db.yml
      service: db

  backend:
    depends_on:
      - db
      - redis_db
    extends:
      file: ./blockscout-5.4.0-beta/docker-compose/services/backend.yml
      service: backend
    build:
      context: ..
      dockerfile: ./docker/Dockerfile
      args:
        CACHE_EXCHANGE_RATES_PERIOD: ""
        API_V1_READ_METHODS_DISABLED: "false"
        DISABLE_WEBAPP: "false"
        API_V1_WRITE_METHODS_DISABLED: "false"
        CACHE_TOTAL_GAS_USAGE_COUNTER_ENABLED: ""
        CACHE_ADDRESS_WITH_BALANCES_UPDATE_INTERVAL: ""
        ADMIN_PANEL_ENABLED: ""
        RELEASE_VERSION: 5.4.0
    links:
      - db:database
    environment:
        ETHEREUM_JSONRPC_HTTP_URL: http://host.docker.internal:8545/
        ETHEREUM_JSONRPC_TRACE_URL: http://host.docker.internal:8545/
        ETHEREUM_JSONRPC_WS_URL: ws://host.docker.internal:8546/
        CHAIN_ID: 1217

  visualizer:
    extends:
      file: ./blockscout-5.4.0-beta/docker-compose/services/visualizer.yml
      service: visualizer

  sig-provider:
    extends:
      file: ./blockscout-5.4.0-beta/docker-compose/services/sig-provider.yml
      service: sig-provider

  frontend:
    depends_on:
      - backend
    extends:
      file: ./blockscout-5.4.0-beta/docker-compose/services/frontend.yml
      service: frontend

  stats-db-init:
    extends:
      file: ./blockscout-5.4.0-beta/docker-compose/services/stats.yml
      service: stats-db-init

  stats-db:
    depends_on:
      - backend
    extends:
      file: ./blockscout-5.4.0-beta/docker-compose/services/stats.yml
      service: stats-db

  stats:
    depends_on:
      - stats-db
    extends:
      file: ./blockscout-5.4.0-beta/docker-compose/services/stats.yml
      service: stats

  proxy:
    depends_on:
      - backend
      - frontend
      - stats
    extends:
      file: ./blockscout-5.4.0-beta/docker-compose/services/nginx.yml
      service: proxy

EOF