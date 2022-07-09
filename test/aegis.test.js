/* global describe it ethers before beforeEach afterEach overwriteArtifact */
const { expect } = require('chai');
const poseidonGenContract = require('circomlibjs/src/poseidon_gencontract');
const prover = require('../src/prover');
const utils = require('../src/utils');
const MerkleTree = require('../src/merkle');
const { getVerificationKeys } = require('../src/verificationKeys');

let aegis;
let nft;
let alice;
let bob;
let merkleTree;
let aegisAlice;
let aegisBob;
let nftAlice;
let snapshotId;
const TREE_DEPTH = 8;

async function getCommitmentFromTx(tx) {
  const rc = await tx.wait();
  const event = rc.events.find((ev) => ev.event === 'Commitment');
  const [commitment] = event.args;
  return commitment.toBigInt();
}

describe('Aegis', () => {
  beforeEach(async () => {
    merkleTree = new MerkleTree(TREE_DEPTH);
    snapshotId = await ethers.provider.send('evm_snapshot');
  });
  afterEach(async () => {
    await await ethers.provider.send('evm_revert', [snapshotId]);
  });
  before(async () => {
    const vkeys = getVerificationKeys();

    [, alice, bob] = await ethers.getSigners();
    // Deploy test token
    const NFT = await ethers.getContractFactory('NFT');
    nft = await NFT.deploy('Aegis', 'AGS');
    nftAlice = nft.connect(alice);

    // Deploy Poseidon library
    await overwriteArtifact('PoseidonT3', poseidonGenContract.createCode(2));

    const PoseidonT3 = await ethers.getContractFactory('PoseidonT3');
    const poseidonT3 = await PoseidonT3.deploy();

    // Deploy Aegis
    const Aegis = await ethers.getContractFactory('Aegis', {
      libraries: {
        PoseidonT3: poseidonT3.address,
      },
    });

    aegis = await Aegis.deploy();
    await aegis.initializeAegis(vkeys);

    aegisAlice = aegis.connect(alice);
    aegisBob = aegis.connect(bob);
  });

  it('Alice should swap her NFT for payment from Bob', async () => {
    // Mint NFT for Alice
    const NFT_ID = 10n;
    const nftKeyDeposit = utils.getKeyPair();
    await nftAlice.mintUniqueTokenTo(alice.address, NFT_ID);
    // Approve Aegis as an operator for Alice's NFT
    await nftAlice.approve(aegis.address, NFT_ID);
    // Deposit Alice's NFT into Aegis
    let tx = await aegisAlice.depositNFT(NFT_ID, nft.address, nftKeyDeposit.publicKey);
    let cmt = await getCommitmentFromTx(tx);
    merkleTree.insertLeaves([cmt]);

    // Bob deposit 2x10 ethers into Aegis
    const depositAmount = ethers.utils.parseEther('10').toBigInt();
    const fundKeys = [utils.getKeyPair(), utils.getKeyPair()];
    tx = await aegisBob.depositFunds(fundKeys[0].publicKey, { value: depositAmount });
    cmt = await getCommitmentFromTx(tx);
    merkleTree.insertLeaves([cmt]);
    tx = await aegisBob.depositFunds(fundKeys[1].publicKey, { value: depositAmount });
    cmt = await getCommitmentFromTx(tx);
    merkleTree.insertLeaves([cmt]);

    // Alice generates NFT commitment for Bob
    const uid = BigInt(
      ethers.utils.solidityKeccak256(['uint256', 'uint160'], [NFT_ID, BigInt(nft.address)]),
    ) % utils.SNARK_SCALAR_FIELD;

    // Bob generates a public key to receive the NFT
    const bobNFTKey = utils.getKeyPair();
    // Bob generates a public to receive the change
    const bobChangeKey = utils.getKeyPair();
    // Alice generates a public key to receive the payment
    const alicePaymentKey = utils.getKeyPair();

    // nftCommitment will be used as a massage by Bob
    const nftCommitment = utils.getCommitment(uid, bobNFTKey.publicKey);

    // Bob generates payment commitment for Alice
    const paymentAmount = ethers.utils.parseEther('15').toBigInt();
    const changeAmount = depositAmount * 2n - paymentAmount;
    // paymentCommitment will be used as a massage by Alice
    const paymentCommitment = utils.getCommitment(paymentAmount, alicePaymentKey.publicKey);

    // Alice generates a tx to send her NFT to Bob
    const ownParams = await prover.generateProof(
      paymentCommitment,
      [uid],
      [nftKeyDeposit],
      [uid],
      [bobNFTKey],
      merkleTree,
      false,
    );

    // Bob generates a tx to send payment to Alice
    const jsParams = await prover.generateProof(
      nftCommitment,
      [depositAmount, depositAmount],
      fundKeys,
      [paymentAmount, changeAmount],
      [alicePaymentKey, bobChangeKey],
      merkleTree,
      true,
    );
    // A relayer forwards both transactions to Aegis
    tx = await aegis.swap(jsParams, ownParams);

    const commitments = [...jsParams.commitments, ownParams.commitment];
    merkleTree.insertLeaves(commitments);

    // Alice withdraws her payment from Aegis
    const dummyKey = utils.getKeyPair();
    const aliceJS = await prover.generateProof(
      0n,
      [paymentAmount, 0n],
      [alicePaymentKey, dummyKey],
      [paymentAmount, 0n],
      [{ publicKey: BigInt(alice.address) }, dummyKey],
      merkleTree,
      true,
    );
    // TX sent by a relayer
    const oldBalance = (await ethers.provider.getBalance(alice.address)).toBigInt();
    await aegis.withdrawFunds(paymentAmount, alice.address, aliceJS);
    const newBalance = (await ethers.provider.getBalance(alice.address)).toBigInt();
    await expect(oldBalance + paymentAmount).to.equal(newBalance);

    // Bob withdraws his NFT from Aegis
    const bobNFT = await prover.generateProof(
      0n,
      [uid],
      [bobNFTKey],
      [uid],
      [{ publicKey: BigInt(bob.address) }],
      merkleTree,
      false,
    );
    // TX sent by a relayer
    await aegis.withdrawNFT(NFT_ID, nft.address, bob.address, bobNFT);
    const res = await nft.ownerOf(NFT_ID);
    expect(res).to.equal(bob.address);
  });
});
