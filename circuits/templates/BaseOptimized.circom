pragma circom 2.0.0;
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/babyjub.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/gates.circom";
include "../../node_modules/circomlib/circuits/mux1.circom";
include "./MerkleProof.circom";
include "./Note.circom";
include "./Nullifier.circom";
include "./PublicKey.circom";
include "./SHA256.circom";


template BaseOptimized(nInputs, mOutputs, MerkleTreeDepth) {

    //shared
    signal input hash;
    signal input message; //public

    //join
    signal input valuesIn[nInputs];
    signal input privateKeys[nInputs];
    signal input merkleRoot; //public   
    signal input pathElements[nInputs][MerkleTreeDepth];
    signal input pathIndices[nInputs];
    signal input nullifiers[nInputs]; //public

    //split
    signal input recipientPK[mOutputs]; 
    signal input valuesOut[mOutputs];
    signal input commitmentsOut[mOutputs]; //public 

    component sha256Comp = SHA256(2+nInputs+mOutputs);
    sha256Comp.in[0] <== message;
    sha256Comp.in[1] <== merkleRoot;
    for(var i=0; i< nInputs; i++) {
        sha256Comp.in[i+2] <== nullifiers[i];
    }
    for(var i=0; i< mOutputs; i++) {
        sha256Comp.in[i+2+nInputs] <== commitmentsOut[i];
    }
    sha256Comp.out === hash;

    var inputsTotal = 0;
    var outputsTotal = 0;

    component publicKeyComps[nInputs];
    component inputNoteComps[nInputs];
    component nullfierComps[nInputs];
    component merkleComp[nInputs];
    component isDummyInputComps[nInputs];
    component checkEqualIfIsNotDummyComps[nInputs];

    //verify input notes
    for(var i =0; i<nInputs; i++){
        
        //derive pubkey from the spending key
        publicKeyComps[i] = PublicKey();
        publicKeyComps[i].privateKey <== privateKeys[i];

        //verify nullifier
        nullfierComps[i] = Nullifier();
        nullfierComps[i].privateKey <== privateKeys[i];
        nullfierComps[i].pathIndex <== pathIndices[i];
        nullfierComps[i].out === nullifiers[i];

        //compute note commitment
        inputNoteComps[i] = Note();
        inputNoteComps[i].value <== valuesIn[i];
        inputNoteComps[i].publicKey <== publicKeyComps[i].out;

        //verify merkleComp proof on the note commitment
        merkleComp[i] = MerkleProof(MerkleTreeDepth);
        merkleComp[i].leaf <== inputNoteComps[i].out;
        merkleComp[i].pathIndices <== pathIndices[i];
        for(var j=0; j< MerkleTreeDepth; j++) {
            merkleComp[i].pathElements[j] <== pathElements[i][j];
        }

        //dummy note if value = 0
        isDummyInputComps[i] = IsZero();
        isDummyInputComps[i].in <== valuesIn[i];

        //Check merkle proof verification if NOT isDummyInputComps
        checkEqualIfIsNotDummyComps[i] = ForceEqualIfEnabled();
        checkEqualIfIsNotDummyComps[i].enabled <== 1-isDummyInputComps[i].out;
        checkEqualIfIsNotDummyComps[i].in[0] <== merkleRoot;
        checkEqualIfIsNotDummyComps[i].in[1] <== merkleComp[i].root;

        inputsTotal += valuesIn[i];
    }

    component outputNoteComps[mOutputs];

    //verify output notes
    for(var i =0; i<mOutputs; i++){

        //verify commitment of output note
        outputNoteComps[i] = Note();
        outputNoteComps[i].value <== valuesOut[i];
        outputNoteComps[i].publicKey <== recipientPK[i];
        outputNoteComps[i].out === commitmentsOut[i];

        //accumulates output amount
        outputsTotal += valuesOut[i]; //no overflow as long as mOutputs is small e.g. 3
    }

    //check that inputs and outputs amounts are equal
    inputsTotal === outputsTotal;
}
