// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma abicoder v2;

uint256 constant SNARK_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

struct G1Point {
    uint256 x;
    uint256 y;
}
struct G2Point {
    uint256[2] x;
    uint256[2] y;
}

struct VerifyingKey {
    G1Point alpha1;
    G2Point beta2;
    G2Point gamma2;
    G2Point delta2;
    G1Point[] ic;
}

struct SnarkProof {
    G1Point a;
    G2Point b;
    G1Point c;
}

struct OwnershipTransaction {
    SnarkProof proof;
    uint treeNumber;
    uint256 message;
    uint256 merkleRoot;
    uint256 commitment;
    uint256 nullifier;
}

struct JoinSplitTransaction {
    SnarkProof proof;
    uint256 treeNumber;
    uint256 message;
    uint256 merkleRoot;
    uint256[2] commitments;
    uint256[2] nullifiers;
}
