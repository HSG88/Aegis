/* global describe it before beforeEach afterEach */
const fs = require('fs');
const snarkjs = require('snarkjs');
const crypto = require('crypto');
const { stringifyBigInts } = require('../src/utils');

const { zKey, r1cs } = snarkjs;

describe('Setup Phase', async () => {
  const TREE_DEPTH = 16;
  const ptauPath = './build/powersOfTau28_hez_final_20.ptau';
  let startTime = 0;
  let label = '';
  const seperator = '#########################################\n';

  describe('JoinSplit', async () => {
    const path = './report/JoinSplit';
    const jsTmp = './build/JoinsSplit.tmp';

    before(async () => {
      fs.appendFileSync(path, seperator);
      fs.appendFileSync(path, `Merkle Tree Depth = ${TREE_DEPTH}\n`);
    });

    beforeEach(async () => {
      startTime = performance.now();
    });

    afterEach(async () => {
      const time = Math.round(performance.now() - startTime);
      fs.appendFileSync(path, `${label}: ${time}\n`);
    });

    it('Should prepare phase-2 of the JoinSplit trusted setup', async () => {
      label = 'Setup';
      const jsR1CS = './build/JoinSplit.r1cs';
      const data = await r1cs.info(jsR1CS);
      fs.appendFileSync(path, `Constraints: ${data.nConstraints}\nWitness: ${data.nPrvInputs}\nStatement: ${data.nPubInputs}\n`);
      await zKey.newZKey(jsR1CS, ptauPath, jsTmp);
    });

    it('Should contribute to JoinSplit setup', async () => {
      label = 'Contribute';
      const jsPK = './build/JoinSplit.zkey';
      const jsVK = './build/JoinSplit.json';
      const random = crypto.randomBytes(32).toString('hex');
      await zKey.contribute(jsTmp, jsPK, 'Alice', random);
      const vKey = await zKey.exportVerificationKey(jsPK);
      const vk = JSON.stringify(stringifyBigInts(vKey), null, 1);
      fs.writeFileSync(jsVK, vk);
      fs.rmSync(jsTmp);
    });
  });

  describe('Ownership', async () => {
    const path = './report/Ownership';
    const ownTmp = './build/OwnerShip.tmp';

    before(async () => {
      fs.appendFileSync(path, seperator);
      fs.appendFileSync(path, `Merkle Tree Depth = ${TREE_DEPTH}\n`);
    });

    beforeEach(async () => {
      startTime = performance.now();
    });

    afterEach(async () => {
      const time = Math.round(performance.now() - startTime);
      fs.appendFileSync(path, `${label}: ${time}ms\n`);
    });

    it('Should prepare phase-2 of the Ownership trusted setup', async () => {
      label = 'Setup';
      const ownR1CS = './build/OwnerShip.r1cs';
      const data = await r1cs.info(ownR1CS);
      fs.appendFileSync(path, `Constraints: ${data.nConstraints}\nWitness: ${data.nPrvInputs}\nStatement: ${data.nPubInputs}\n`);
      await zKey.newZKey(ownR1CS, ptauPath, ownTmp);
    });

    it('Should contribute to Ownership setup', async () => {
      label = 'Contribute';
      const ownPK = './build/OwnerShip.zkey';
      const ownVK = './build/OwnerShip.json';
      const random = crypto.randomBytes(32).toString('hex');
      await zKey.contribute(ownTmp, ownPK, 'Alice', random);
      const vKey = await zKey.exportVerificationKey(ownPK);
      const vk = JSON.stringify(stringifyBigInts(vKey), null, 1);
      fs.writeFileSync(ownVK, vk);
      fs.rmSync(ownTmp);
    });
  });
});
