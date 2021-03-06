/* eslint-disable no-plusplus */
const snarkjs = require('snarkjs');
const utils = require('./utils');

const pKeys = {
  js: './build/JoinSplit.zkey',
  own: './build/Ownership.zkey',
};

const wasm = {
  js: './build/JoinSplit.wasm',
  own: './build/Ownership.wasm',
};

function formatProof(proof) {
  return {
    a: proof.pi_a.slice(0, 2),
    b: proof.pi_b.map((x) => x.reverse()).slice(0, 2),
    c: proof.pi_c.slice(0, 2),
  };
}

function chooseArtifacts(isJoinSplit) {
  if (isJoinSplit) {
    return { ws: wasm.js, pk: pKeys.js };
  }
  return { ws: wasm.own, pk: pKeys.own };
}

async function generateProof(
  message,
  valuesIn,
  keysIn,
  valuesOut,
  keysOut,
  merkleTree,
  isJoinSplit,
) {
  const commitmentsOut = [];
  const nullifiers = [];
  const pathIndices = [];
  let pathElements = [];
  for (let i = 0; i < valuesIn.length; i++) {
    const cmt = utils.getCommitment(valuesIn[i], keysIn[i].publicKey);
    if (valuesIn[i] === 0n) {
      pathIndices[i] = 0;
      pathElements.push(new Array(merkleTree.depth).fill(0n));
    } else {
      const merkleProof = merkleTree.generateProof(cmt);
      pathIndices[i] = merkleProof.indices;
      pathElements.push(merkleProof.elements);
    }
    nullifiers[i] = utils.getNullifier(keysIn[i].privateKey, pathIndices[i]);
  }
  for (let i = 0; i < valuesOut.length; i++) {
    commitmentsOut[i] = utils.getCommitment(valuesOut[i], keysOut[i].publicKey);
  }
  pathElements = pathElements.flat(1);

  const { ws, pk } = chooseArtifacts(isJoinSplit);

  const circuitInputs = {
    message,
    valuesIn,
    privateKeys: keysIn.map((k) => k.privateKey),
    merkleRoot: merkleTree.root,
    pathElements,
    pathIndices,
    nullifiers,
    recipientPK: keysOut.map((k) => k.publicKey),
    valuesOut,
    commitmentsOut,
  };

  const fullProof = await snarkjs.groth16.fullProve(circuitInputs, ws, pk);
  const solidityProof = formatProof(fullProof.proof);
  if (isJoinSplit) {
    return {
      proof: solidityProof,
      treeNumber: 0,
      message,
      merkleRoot: merkleTree.root,
      nullifiers,
      commitments: commitmentsOut,
    };
  }
  return {
    proof: solidityProof,
    treeNumber: 0,
    message,
    merkleRoot: merkleTree.root,
    nullifier: nullifiers[0],
    commitment: commitmentsOut[0],
  };
}
module.exports = {
  generateProof,
};
