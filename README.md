# Blockchain Hyperledger Besu
Cria uma rede blockchain hyperledger besu para fins de estudos voltados ao DREX: CBDC brasileira. 

## Pré-requisitos
* Docker compose
* Shell script

## Features
* Gera todos os arquivos e diretórios necessários
* Cria 1 bootnode e 3 nós
* Configura o blockscout explorer

## Tecnologias utilizadas
* Shell Script
* [Blockscout](https://www.blockscout.com)
* [Hyperledger Besu](https://www.hyperledger.org/projects/besu)
* [Docker](https://docs.docker.com/)

## Instalação

```bash
sudo chmod +x install.sh
./install.sh
```

## Rodar a aplicação

```bash
docker compose up -d
```

Acesse o explorer em http://localhost

Exemplo de configuração do hardhat `hardhat.config.ts`:

```typescript
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

import "dotenv/config"

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    besu: {
      url: "http://localhost:8545",
      accounts: [String(process.env.PRIVATE_KEY)],
      gasPrice: 0,
      chainId: 1217
    }
  },
  etherscan: {
    apiKey: {
      besu: "abc"
    },
    customChains: [
      {
        network: "besu",
        chainId: 1217,
        urls: {
          apiURL: "http://localhost/api/",
          browserURL: "http://localhost/"
        }
      }
    ]
  },
  sourcify: {
    enabled: true
  }
};


export default config;

```



## Autor
[Vagner Ribeiro](https://www.linkedin.com/in/vagner-ribeiro/)