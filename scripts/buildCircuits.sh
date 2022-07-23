#!/bin/zsh

set -e

cd "$(dirname "$0")"

mkdir -p ../build

cd ../build

ptau=powersOfTau28_hez_final_20.ptau

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