pragma circom 2.0.0;
include "../../node_modules/circomlib/circuits/poseidon.circom";

template PublicKey(){
  signal input privateKey;
  signal output out;
  component hasher = Poseidon(1);
  hasher.inputs[0] <== privateKey;
  out <== hasher.out;
}