pragma circom 2.0.0;
include "./templates/Base.circom";

component main {public [message, merkleRoot, nullifiers, commitmentsOut]} =  Base(2,2,16);