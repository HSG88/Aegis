pragma circom 2.0.0;
include "../../node_modules/circomlib/circuits/poseidon.circom";

template Nullifier(){
  signal input privateKey;
  signal input pathIndex;
  signal output out;

  component hasher = Poseidon(2);
  hasher.inputs[0] <== privateKey;
  hasher.inputs[1] <== pathIndex;
  out <== hasher.out;
}