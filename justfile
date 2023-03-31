set dotenv-load

# Path and Variables
ORG := "aetheras-io"
PROJECT := "banksy-rs"
REPO := "https://github.com" / ORG / PROJECT
ROOT_DIR := justfile_directory()
OUTPUT_DIR := ROOT_DIR / "out"
TESTNET_DIR := OUTPUT_DIR / "testnet"
TEST_ADDR := "0x003533CD36aC980768B510F5C57E00CE4c0229D5"
TEST_KEY := "0x9cbc61f079e82f0d9d3989a99f5cfe4aef68cbec8063b821fd41e994ea131c79" 
BOBTH_ADDR := "0x3cd0a705a2dc65e5b1e1205896baa2be8a07c6e0"
BOBTH_KEY := "0x8075991ce870b93a8870eca0c0f91913d12f47948ca0fd25b49c6fa7cdbeee8b"
RENDERER_ADDR := "0xD997826264FE81eAc38946195BFDCF6813ab0Be4"
#$(shell mkdir -p ${OUTPUT_DIR})

clean:
    forge clean

project-tree:
    tree -I 'lib|out|node_modules|cache|README*|*.lock|public|package.json|foundry.toml|tsconfig.json'

deps:
    curl -L https://foundry.paradigm.xyz | bash
    foundryup

# https://onbjerg.github.io/foundry-book/forge/dependencies.html
deps-oz:
    forge install Brechtpd/base64
    forge install dapphub/ds-test
    forge install openzeppelin/openzeppelin-contracts@v4.5.0

# Build & test
build:
    forge build --extra-output metadata
test:
    forge test -vvvv 
flatten: 
    @forge flatten ./src/NftTemplate.sol > ./out/NftTemplate.flat.sol
flatten-renderer: 
    @forge flatten ./src/NftTemplateRenderer.sol > ./out/NftTemplateRenderer.flat.sol

# estimate :; ./scripts/estimate-gas.sh ${contract}
# size   :; ./scripts/contract-size.sh ${contract}
abi-out:
    jq '.abi' ./out/NftTemplate.sol/NftTemplate.json > ./out/NftTemplateAbi.json

testnet:
    docker run --rm -p 8545:8545 -p 8545:8545 --name geth-dev gcr.io/aetheras-io/banksy-testnet:latest --dev --execution=native --ws-external --rpc-external --sealing 3000 -linfo,pallet_ethereum=trace,evm=trace


TESTNET_PARAMS := "--rpc-url http://localhost:8545 --private-key " + BOBTH_KEY
deploy-testnet: (_deploy TESTNET_PARAMS)

GOERLI_PARAMS := "-i --rpc-url https://rpc.ankr.com/eth_goerli --gas-price 250000000000" 
deploy-goerli: (_deploy GOERLI_PARAMS)

AMX_TESTNET_PARAMS := "-i --rpc-url https://aminoxtestnet.node.alphacarbon.network --gas-price 250000000000" 
deploy-amx-testnet: (_deploy AMX_TESTNET_PARAMS)

_deploy params:
    #!/usr/bin/env bash
    echo {{params}}
    render_address=$( forge create {{params}} --legacy NftTemplateRenderer | grep 'Deployed to' | sed -e 's#.*Deployed to: \(\)#\1#' )
    echo "Render Address:" ${render_address}
    nft_address=$( forge create {{params}} --legacy NftTemplate --constructor-args ${render_address} | grep 'Deployed to' | sed -e 's#.*Deployed to: \(\)#\1#' )
    echo "NFT Address:" ${nft_address}

_deploy_pure_nft params:
    #!/usr/bin/env bash
    nft_address=$( forge create {{params}} --legacy NftTemplate --constructor-args {{RENDERER_ADDR}} | grep 'Deployed to' | sed -e 's#.*Deployed to: \(\)#\1#' )
    echo "NFT Address:" ${nft_address}
