const utils = require('./utils');

class MerkleTree {
  constructor(depth) {
    this.depth = depth;
    this.zeros = MerkleTree.getZeroValueLevels(depth);
    this.tree = Array(depth)
      .fill(0)
      .map(() => []);
    this.tree[depth] = [MerkleTree.hashLeftRight(this.zeros[depth - 1], this.zeros[depth - 1])];
  }

  rebuildSparseTree() {
    for (let level = 0; level < this.depth; level += 1) {
      this.tree[level + 1] = [];

      for (let pos = 0; pos < this.tree[level].length; pos += 2) {
        this.tree[level + 1].push(
          MerkleTree.hashLeftRight(
            this.tree[level][pos],
            this.tree[level][pos + 1] ?? this.zeros[level],
          ),
        );
      }
    }
  }

  insertLeaves(leaves) {
    // eslint-disable-next-line no-param-reassign
    leaves = leaves.map(BigInt);

    // Add leaves to bottom of tree
    this.tree[0] = this.tree[0].concat(leaves);

    // Rebuild tree
    this.rebuildSparseTree();
  }

  getLeaves() {
    return this.tree[0];
  }

  generateProof(element) {
    // eslint-disable-next-line no-param-reassign
    element = BigInt(element);

    // Initialize of proof elements
    const elements = [];

    // Initialize indicies string (binary, will be parsed to bigint)
    const indices = [];

    // Get initial index
    let index = this.tree[0].indexOf(element);

    if (index === -1) {
      throw new Error(`Couldn't find ${element} in the MerkleTree number: ${this.treeNumber}`);
    }

    // Loop through each level
    for (let level = 0; level < this.depth; level += 1) {
      if (index % 2 === 0) {
        // If index is even get element on right
        elements.push(this.tree[level][index + 1] ?? this.zeros[level]);

        // Push bit to indices
        indices.push('0');
      } else {
        // If index is odd get element on left
        elements.push(this.tree[level][index - 1]);

        // Push bit to indices
        indices.push('1');
      }

      // Get index for next level
      index = Math.floor(index / 2);
    }

    return {
      element,
      elements,
      indices: BigInt(`0b${indices.reverse().join('')}`),
      root: this.root,
    };
  }

  get root() {
    return this.tree[this.depth][0];
  }

  static hashLeftRight(left, right) {
    return utils.poseidon([left, right]);
  }

  static getZeroValue() {
    return utils.keccak256(Buffer.from('Aegis', 'utf8'));
  }

  static getZeroValueLevels(depth) {
    // Initialize empty array for levels
    const levels = [];

    // First level should be the leaf zero value
    levels.push(MerkleTree.getZeroValue());

    // Loop through remaining levels to root
    for (let level = 1; level < depth; level += 1) {
      // Push left right hash of level below's zero level
      levels.push(MerkleTree.hashLeftRight(levels[level - 1], levels[level - 1]));
    }
    return levels;
  }
}

module.exports = MerkleTree;
