# Aegis
This is the proof of concept presented in our paper "Aegis: Privacy Preserving Market for Non-Fungible Tokens".
## Getting started 
- Install [Node.js](https://nodejs.org/en/)
- Install [Circom 2](https://docs.circom.io/getting-started/installation/)
- Run `npm i` to install dependancies
- Run `npm run build:circuits` to build the zkSNARK artifacts
- Run `npx hardhat test` to test a full scenario of for list of commands

## Notes 
- To change the Merkle tree depth:
  * Update `TREE_DEPTH` in `contracts\Commitments.sol` 
  * Update the last parameter in `circuits\*.circom`
  * Update `TREE_DEPTH` in `test\aegis.test.js`
  * Run `npm run build` to rebuild the artifacts
- To measure the circuit R1CS constraints: 
  - Make sure you have built the artifacts by running `npm run builds`
  - `cd /build`
  - Run `npx snarkjs r1cs info #x` where `#x` is the `*.r1cs` file (e.g. `JoinSplit.r1cs`)
