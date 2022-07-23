// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma abicoder v2;

import { SNARK_SCALAR_FIELD } from "./Globals.sol";

import { PoseidonT3 } from "./Poseidon.sol";

contract Commitments {
  mapping(uint256 => mapping(uint256 => bool)) public nullifiers;
  uint256 internal treeDepth;
  uint256 public constant ZERO_VALUE = uint256(keccak256("Aegis")) % SNARK_SCALAR_FIELD;
  uint256 internal nextLeafIndex;
  uint256 public merkleRoot;
  uint256 private newTreeRoot;
  uint256 public treeNumber;
  uint256[] public zeros;
  uint256[] private filledSubTrees;
  mapping(uint256 => mapping(uint256 => bool)) public rootHistory;

  function initializeCommitments(uint256 _treeDepth) internal {

    treeDepth = _treeDepth;
    filledSubTrees = new uint256[](treeDepth);
    zeros = new uint256[](treeDepth);
    zeros[0] = ZERO_VALUE;
    uint256 currentZero = ZERO_VALUE;
    for (uint256 i = 0; i < treeDepth; i++) {
      zeros[i] = currentZero;
      currentZero = hashLeftRight(currentZero, currentZero);
    }
    newTreeRoot = merkleRoot = currentZero;
    rootHistory[treeNumber][currentZero] = true;
  }

  function hashLeftRight(uint256 _left, uint256 _right) public pure returns (uint256) {
    return PoseidonT3.poseidon([
      _left,
      _right
    ]);
  }

  function insertLeaves(uint256[] memory _leafHashes) internal {
    uint256 count = _leafHashes.length;
    if ((nextLeafIndex + count) >= (2 ** treeDepth)) {
      newTree(); 
    }
    uint256 levelInsertionIndex = nextLeafIndex;
    nextLeafIndex += count;

    uint256 nextLevelHashIndex;
    uint256 nextLevelStartIndex;

    for (uint256 level = 0; level < treeDepth; level++) {
      nextLevelStartIndex = levelInsertionIndex >> 1;
      uint256 insertionElement = 0;

      if (levelInsertionIndex % 2 == 1) {
        nextLevelHashIndex = (levelInsertionIndex >> 1) - nextLevelStartIndex;
        _leafHashes[nextLevelHashIndex] = hashLeftRight(filledSubTrees[level], _leafHashes[insertionElement]);

        insertionElement += 1;
        levelInsertionIndex += 1;
      }

      for (insertionElement; insertionElement < count; insertionElement += 2) {
        uint256 right;

        if (insertionElement < count - 1) {
          right = _leafHashes[insertionElement + 1];
        } else {
          right = zeros[level];
        }

        if (insertionElement == count - 1 || insertionElement == count - 2) {
          filledSubTrees[level] = _leafHashes[insertionElement];
        }

        nextLevelHashIndex = (levelInsertionIndex >> 1) - nextLevelStartIndex;

        _leafHashes[nextLevelHashIndex] = hashLeftRight(_leafHashes[insertionElement], right);
        levelInsertionIndex += 2;
      }
      levelInsertionIndex = nextLevelStartIndex;
      count = nextLevelHashIndex + 1;
    }
     merkleRoot = _leafHashes[0];
    rootHistory[treeNumber][merkleRoot] = true;
  }

  function newTree() internal {
    merkleRoot = newTreeRoot;
    nextLeafIndex = 0;
    treeNumber++;
  }
}
