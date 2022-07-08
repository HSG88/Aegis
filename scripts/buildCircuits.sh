#!/bin/zsh

set -e

cd "$(dirname "$0")"

mkdir -p ../build

cd ../build

ptau=powersOfTau28_hez_final_18.ptau

if [ -f $ptau ]; then
    echo "$ptau already exists. Skipping."
else
    echo 'Downloading $ptau'
    curl https://hermez.s3-eu-west-1.amazonaws.com/$ptau -o $ptau
fi

if ! ${CIRCOM:-circom} ../circuits/JoinSplit.circom --r1cs --wasm ||
        ! [[ -s ./JoinSplit_js/JoinSplit.wasm ]]

then
    echo >&2 "JoinSplit compilation failed"
    exit 1
fi

if ! ${CIRCOM:-circom} ../circuits/Ownership.circom --r1cs --wasm ||
        ! [[ -s ./Ownership_js/Ownership.wasm ]]
then
    echo >&2 "Ownership compilation failed"
    exit 1
fi


echo "Circuit compilation succeeded"

mv ./JoinSplit_js/JoinSplit.wasm ./
mv ./Ownership_js/Ownership.wasm ./

rm -r ./JoinSplit_js
rm -r ./Ownership_js

snarkjs=../node_modules/.bin/snarkjs

echo "Running trusted setup"
$snarkjs groth16 setup JoinSplit.r1cs ./$ptau tmp_0000.zkey
$snarkjs zkey contribute tmp_0000.zkey tmp_0001.zkey --name="First contribution" -v -e="Random entropy"
$snarkjs zkey beacon tmp_0001.zkey JoinSplit.zkey 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon phase2"
$snarkjs zkey export verificationkey JoinSplit.zkey JoinSplit.json
rm tmp*


$snarkjs groth16 setup Ownership.r1cs ./$ptau tmp_0000.zkey
$snarkjs zkey contribute tmp_0000.zkey tmp_0001.zkey --name="First contribution" -v -e="Random entropy"
$snarkjs zkey beacon tmp_0001.zkey Ownership.zkey 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon phase2"
$snarkjs zkey export verificationkey Ownership.zkey Ownership.json
rm tmp*

echo "Trusted setup completed successfully"