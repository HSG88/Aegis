pragma circom 2.0.0;
include "../../node_modules/circomlib/circuits/poseidon.circom";

template Note(){
  signal input value;
  signal input publicKey;
  signal output out;

  component hasher = Poseidon(2);
  hasher.inputs[0] <== value;
  hasher.inputs[1] <== publicKey;
  out <== hasher.out;
}