# ACT Token Contracts 

## Project Structure

```tree
├── justfile                        ; All Scripts and Pipelines
├── lib                             ; Third party solidity dependencies
├── remappings.txt                  ; Solidity library path remappings
└── src                             ; Smart Contracts
    ├── NftTemplate.sol             ; Modern Solidity ERC721 Token
    └── NftTemplateRenderer.sol     ; Modern Solidity ERC721 Token Renderer

```

## Dependencies
- Docker
- Curl

## Getting Started
### Development
Development should occur in "./src" and "./src/test".  
```sh
# Download dependencies
just deps

# Build the Smart Contracts
just build

# Export the ABI's "./out" and "/frontend/src"
just abi-out
```

### Local Deployment
```sh
# starts a local aminox testnet (requires docker)
just testnet

# deploy Payments.sol to Local testnet
just deploy-testnet
```

## Deployment Information
### Goerli(ETH) Testnet
- **NFT Template(ERC-721)**:
    - Deployed at: `0xd605F2d19f302e0F0E69093AcACe7cfa4945FEDf`
    - Owner: `0xAA595A36b94D3230961E645733CA6fFc73A6123F`
    - Creation: https://goerli.etherscan.io/tx/0xc55234254233470d3c693521f9f92f659e34470dbdd53360874256df882f30ce
    - Token Explorer: https://goerli.etherscan.io/address/0xd605F2d19f302e0F0E69093AcACe7cfa4945FEDf

- **Renderer**:
    - Deployed at: `0xD997826264FE81eAc38946195BFDCF6813ab0Be4`
    - Creation: https://goerli.etherscan.io/tx/0x5f93026b8a77e6566aeeb93bd83fa2656c58f0e825c885a551ed746203a6866e
