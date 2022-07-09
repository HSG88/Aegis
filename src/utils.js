const crypto = require('crypto');
const { poseidon } = require('circomlibjs');
const ethers = require('ethers');

const SNARK_SCALAR_FIELD = BigInt(
  '21888242871839275222246405745257275088548364400416034343698204186575808495617',
);

function buffer2BigInt(buf) {
  if (buf.length === 0) {
    return 0n;
  }
  return BigInt(`0x${buf.toString('hex')}`);
}

function getKeyPair() {
  const privateKey = poseidon([buffer2BigInt(Buffer.from(crypto.randomBytes(32)))]);
  const publicKey = poseidon([privateKey]);
  return {
    privateKey,
    publicKey,
  };
}

function getNullifier(privateKey, pathIndices) {
  return poseidon([privateKey, pathIndices]);
}

function getCommitment(value, publicKey) {
  return poseidon([value, publicKey]);
}

function keccak256(preimage) {
  return (
    buffer2BigInt(Buffer.from(ethers.utils.keccak256(preimage).slice(2), 'hex'))
    % SNARK_SCALAR_FIELD
  );
}

module.exports = {
  SNARK_SCALAR_FIELD,
  poseidon,
  getKeyPair,
  getCommitment,
  getNullifier,
  keccak256,
};
