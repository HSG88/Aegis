// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma abicoder v2;

import { SNARK_SCALAR_FIELD } from "./Globals.sol";

import { PoseidonT3 } from "./Poseidon.sol";

/**
 * @title Commitments
 * @author Railgun Contributors
 * @notice Batch Incremental Merkle Tree for commitments
 * @dev Publically accessible functions to be put in RailgunLogic
 * Relevent external contract calls should be in those functions, not here
 */
contract Commitments {
  // Commitment nullifiers (treenumber -> nullifier -> seen)
  mapping(uint256 => mapping(uint256 => bool)) public nullifiers;

  // The tree depth
  uint256 internal constant TREE_DEPTH = 8;

  // Tree zero value
  uint256 public constant ZERO_VALUE = uint256(keccak256("Aegis")) % SNARK_SCALAR_FIELD;

  // Next leaf index (number of inserted leaves in the current tree)
  uint256 internal nextLeafIndex;

  // The Merkle root
  uint256 public merkleRoot;

  // Store new tree root to quickly migrate to a new tree
  uint256 private newTreeRoot;

  // Tree number
  uint256 public treeNumber;

  // The Merkle path to the leftmost leaf upon initialisation. It *should
  // not* be modified after it has been set by the initialize function.
  // Caching these values is essential to efficient appends.
  uint256[TREE_DEPTH] public zeros;

  // Right-most elements at each level
  // Used for efficient upodates of the merkle tree
  uint256[TREE_DEPTH] private filledSubTrees;

  // Whether the contract has already seen a particular Merkle tree root
  // treeNumber -> root -> seen
  mapping(uint256 => mapping(uint256 => bool)) public rootHistory;


  /**
   * @notice Calculates initial values for Merkle Tree
   * @dev OpenZeppelin initializer ensures this can only be called once
   */
  function initializeCommitments() internal {

    // Calculate zero values
    zeros[0] = ZERO_VALUE;

    // Store the current zero value for the level we just calculated it for
    uint256 currentZero = ZERO_VALUE;

    // Loop through each level
    for (uint256 i = 0; i < TREE_DEPTH; i++) {
      // Push it to zeros array
      zeros[i] = currentZero;

      // Calculate the zero value for this level
      currentZero = hashLeftRight(currentZero, currentZero);
    }

    // Set merkle root and store root to quickly retrieve later
    newTreeRoot = merkleRoot = currentZero;
    rootHistory[treeNumber][currentZero] = true;
  }

  /**
   * @notice Hash 2 uint256 values
   * @param _left - Left side of hash
   * @param _right - Right side of hash
   * @return hash result
   */
  function hashLeftRight(uint256 _left, uint256 _right) public pure returns (uint256) {
    return PoseidonT3.poseidon([
      _left,
      _right
    ]);
  }

  /**
   * @notice Calculates initial values for Merkle Tree
   * @dev Insert leaves into the current merkle tree
   * Note: this function INTENTIONALLY causes side effects to save on gas.
   * _leafHashes and _count should never be reused.
   * @param _leafHashes - array of leaf hashes to be added to the merkle tree
   */
  function insertLeaves(uint256[] memory _leafHashes) internal {

    // Get initial count
    uint256 count = _leafHashes.length;

    // Create new tree if current one can't contain new leaves
    // We insert all new commitment into a new tree to ensure they can be spent in the same transaction
    if ((nextLeafIndex + count) >= (2 ** TREE_DEPTH)) { newTree(); }

    // Current index is the index at each level to insert the hash
    uint256 levelInsertionIndex = nextLeafIndex;

    // Update nextLeafIndex
    nextLeafIndex += count;

    // Variables for starting point at next tree level
    uint256 nextLevelHashIndex;
    uint256 nextLevelStartIndex;

    // Loop through each level of the merkle tree and update
    for (uint256 level = 0; level < TREE_DEPTH; level++) {
      // Calculate the index to start at for the next level
      // >> is equivilent to / 2 rounded down
      nextLevelStartIndex = levelInsertionIndex >> 1;

      uint256 insertionElement = 0;

      // If we're on the right, hash and increment to get on the left
      if (levelInsertionIndex % 2 == 1) {
        // Calculate index to insert hash into leafHashes[]
        // >> is equivilent to / 2 rounded down
        nextLevelHashIndex = (levelInsertionIndex >> 1) - nextLevelStartIndex;

        // Calculate the hash for the next level
        _leafHashes[nextLevelHashIndex] = hashLeftRight(filledSubTrees[level], _leafHashes[insertionElement]);

        // Increment
        insertionElement += 1;
        levelInsertionIndex += 1;
      }

      // We'll always be on the left side now
      for (insertionElement; insertionElement < count; insertionElement += 2) {
        uint256 right;

        // Calculate right value
        if (insertionElement < count - 1) {
          right = _leafHashes[insertionElement + 1];
        } else {
          right = zeros[level];
        }

        // If we've created a new subtree at this level, update
        if (insertionElement == count - 1 || insertionElement == count - 2) {
          filledSubTrees[level] = _leafHashes[insertionElement];
        }

        // Calculate index to insert hash into leafHashes[]
        // >> is equivilent to / 2 rounded down
        nextLevelHashIndex = (levelInsertionIndex >> 1) - nextLevelStartIndex;

        // Calculate the hash for the next level
        _leafHashes[nextLevelHashIndex] = hashLeftRight(_leafHashes[insertionElement], right);

        // Increment level insertion index
        levelInsertionIndex += 2;
      }

      // Get starting levelInsertionIndex value for next level
      levelInsertionIndex = nextLevelStartIndex;

      // Get count of elements for next level
      count = nextLevelHashIndex + 1;
    }
 
    // Update the Merkle tree root
    merkleRoot = _leafHashes[0];
    rootHistory[treeNumber][merkleRoot] = true;
  }

  /**
   * @notice Creates new merkle tree
   */
  function newTree() internal {
    // Restore merkleRoot to newTreeRoot
    merkleRoot = newTreeRoot;

    // Existing values in filledSubtrees will never be used so overwriting them is unnecessary

    // Reset next leaf index to 0
    nextLeafIndex = 0;

    // Increment tree number
    treeNumber++;
  }
}
