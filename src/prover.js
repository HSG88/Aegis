/* eslint-disable no-plusplus */
const snarkjs = require('snarkjs');
const fs = require('fs');
const builder = require('./witnessCalculator');
const utils = require('./utils');

const pKeys = {
  js: './build/JoinSplit.zkey',
  jsOptimized: './build/JoinSplitOptimized.zkey',
  own: './build/Ownership.zkey',
  ownOptimized: './build/OwnershipOptimized.zkey',
};

const wasm = {
  js: './build/JoinSplit.wasm',
  jsOptimized: './build/JoinSplitOptimized.wasm',
  own: './build/Ownership.wasm',
  ownOptimized: './build/OwnershipOptimized.wasm',
};

function formatProof(proof) {
  return {
    a: proof.pi_a.slice(0, 2),
    b: proof.pi_b.map((x) => x.reverse()).slice(0, 2),
    c: proof.pi_c.slice(0, 2),
  };
}
async function genWnts(input, wasmFilePath, witnessFileName) {
  const buffer = fs.readFileSync(wasmFilePath);

  return new Promise((resolve, reject) => {
    builder(buffer)
      .then(async (witnessCalculator) => {
        const buff = await witnessCalculator.calculateWTNSBin(input, 0);
        fs.writeFileSync(witnessFileName, buff);
        resolve(witnessFileName);
      })
      .catch((error) => {
        reject(error);
      });
  });
}

function chooseArtifacts(isJoinSplit, isOptimized) {
  if (isJoinSplit) {
    if (isOptimized) {
      return { ws: wasm.jsOptimized, pk: pKeys.jsOptimized };
    }
    return { ws: wasm.js, pk: pKeys.js };
  }
  if (isOptimized) {
    return { ws: wasm.ownOptimized, pk: pKeys.ownOptimized };
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
  isOptimized,
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

  const { ws, pk } = chooseArtifacts(isJoinSplit, isOptimized);

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
  if (isOptimized) {
    const arr = [message, merkleTree.root, nullifiers, commitmentsOut].flat(1);
    // eslint-disable-next-line dot-notation
    circuitInputs['hash'] = utils.sha256(arr) % utils.SNARK_SCALAR_FIELD;
  }
  await genWnts(circuitInputs, ws, 'witness.wtns');
  const fullProof = await snarkjs.groth16.prove(pk, 'witness.wtns', null);
  const solidityProof = formatProof(fullProof.proof);
  if (isJoinSplit) {
    return {
      proof: solidityProof,
      message,
      merkleRoot: merkleTree.root,
      nullifiers,
      commitments: commitmentsOut,
    };
  }
  return {
    proof: solidityProof,
    message,
    merkleRoot: merkleTree.root,
    nullifier: nullifiers[0],
    commitment: commitmentsOut[0],
  };
}
module.exports = {
  generateProof,
};
