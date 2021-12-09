// SPDX-License-Identifier: UNLICENSED
// Based on code from MACI (https://github.com/appliedzkp/maci/blob/7f36a915244a6e8f98bacfe255f8bd44193e7919/contracts/sol/IncrementalMerkleTree.sol)
pragma solidity ^0.8.0;
pragma abicoder v2;

import {SNARK_SCALAR_FIELD} from "./Globals.sol";

import {PoseidonT3} from "./Poseidon.sol";


contract Commitments {
    // Commitment nullifiers
    mapping(uint256 => bool) public nullifiers;

    // The tree depth
    uint256 private constant TREE_DEPTH = 10;

    // Max number of leaves that can be inserted in a single batch
    uint256 internal constant MAX_BATCH_SIZE = 2;

    // Tree zero value
    uint256 private constant ZERO_VALUE =
        uint256(keccak256("Aegis")) % SNARK_SCALAR_FIELD;

    // Next leaf index (number of inserted leaves in the current tree)
    uint256 private nextLeafIndex = 0;

    // The Merkle root
    uint256 public merkleRoot;

    // The Merkle path to the leftmost leaf upon initialisation. It *should
    // not* be modified after it has been set by the initialize function.
    // Caching these values is essential to efficient appends.
    uint256[TREE_DEPTH] private zeros;

    // Right-most elements at each level
    // Used for efficient updates of the merkle tree
    uint256[TREE_DEPTH] private filledSubTrees;

    // Whether the contract has already seen a particular Merkle tree root
    // treeNumber => root => seen
    mapping(uint256 => bool) public rootHistory;

    /**
     * @notice Calculates initial values for Merkle Tree
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
        merkleRoot = currentZero;
        rootHistory[merkleRoot] = true;
    }

    /**
     * @notice Hash 2 uint256 values
     * @param _left - Left side of hash
     * @param _right - Right side of hash
     * @return hash result
     */
    function hashLeftRight(uint256 _left, uint256 _right)
        private
        pure
        returns (uint256)
    {
        return PoseidonT3.poseidon([_left, _right]);
    }

    function insertLeaves(uint256[] memory _leafHashes) internal {
        /*
    Loop through leafHashes at each level, if the leaf is on the left (index is even)
    then hash with zeros value and update subtree on this level, if the leaf is on the
    right (index is odd) then hash with subtree value. After calculating each hash
    push to relevent spot on leafHashes array. For gas efficiency we reuse the same
    array and use the count variable to loop to the right index each time.

    Example of updating a tree of depth 4 with elements 13, 14, and 15
    [1,7,15]    {1}                    1
                                       |
    [3,7,15]    {1}          2-------------------3
                             |                   |
    [6,7,15]    {2}     4---------5         6---------7
                       / \       / \       / \       / \
    [13,14,15]  {3}  08   09   10   11   12   13   14   15
    [] = leafHashes array
    {} = count variable
    */

        // Get initial count
        uint256 count = _leafHashes.length;

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
                nextLevelHashIndex =
                    (levelInsertionIndex >> 1) -
                    nextLevelStartIndex;

                // Calculate the hash for the next level
                _leafHashes[nextLevelHashIndex] = hashLeftRight(
                    filledSubTrees[level],
                    _leafHashes[insertionElement]
                );

                // Increment
                insertionElement += 1;
                levelInsertionIndex += 1;
            }

            // We'll always be on the left side now
            for (
                insertionElement;
                insertionElement < count;
                insertionElement += 2
            ) {
                uint256 right;

                // Calculate right value
                if (insertionElement < count - 1) {
                    right = _leafHashes[insertionElement + 1];
                } else {
                    right = zeros[level];
                }

                // If we've created a new subtree at this level, update
                if (
                    insertionElement == count - 1 ||
                    insertionElement == count - 2
                ) {
                    filledSubTrees[level] = _leafHashes[insertionElement];
                }

                // Calculate index to insert hash into leafHashes[]
                // >> is equivilent to / 2 rounded down
                nextLevelHashIndex =
                    (levelInsertionIndex >> 1) -
                    nextLevelStartIndex;

                // Calculate the hash for the next level
                _leafHashes[nextLevelHashIndex] = hashLeftRight(
                    _leafHashes[insertionElement],
                    right
                );

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
        rootHistory[merkleRoot] = true;
    }
}
