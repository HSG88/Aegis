// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma abicoder v2;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {VerifyingKey, SnarkProof, OwnershipTransaction, JoinSplitTransaction, SNARK_SCALAR_FIELD} from "./Globals.sol";
import {PoseidonT3} from "./Poseidon.sol";
import {Verifier} from "./Verifier.sol";
import {Commitments} from "./Commitments.sol";

contract Aegis is Commitments, Verifier {
    event Nullifier(uint256 indexed nullifier);
    event Commitment(uint256 indexed commitment);

    function initializeAegis(uint256 _treeDepth, VerifyingKey[2] calldata _vk) external {
        Commitments.initializeCommitments(_treeDepth);
        Verifier.initializeVerifier(_vk);
    }

    function depositFunds(uint256 _publicKey) external payable {
        uint256 value = msg.value;
        uint256 commitment = PoseidonT3.poseidon([value, _publicKey]);
        uint256[] memory leaves = new uint256[](1);
        leaves[0] = commitment;
        Commitments.insertLeaves(leaves);
        emit Commitment(commitment);
    }

    function depositNFT(
        uint256 _id,
        IERC721 _nftContract,
        uint256 _publicKey
    ) external {
        _nftContract.transferFrom(msg.sender, address(this), _id);
        uint256 uid = uint256(
            keccak256(abi.encodePacked(_id, address(_nftContract)))
        ) % SNARK_SCALAR_FIELD;
        uint256 commitment = PoseidonT3.poseidon([uid, _publicKey]);
        uint256[] memory leaves = new uint256[](1);
        leaves[0] = commitment;
        Commitments.insertLeaves(leaves);
        emit Commitment(commitment);
    }

    function withdrawFunds(
        uint256 _amount,
        address _recipient,
        JoinSplitTransaction calldata _tx
    ) external {
        uint256 commitment = PoseidonT3.poseidon(
            [_amount, uint256(uint160(_recipient))]
        );

        require(
            commitment == _tx.commitments[0],
            "WithdrawFunds: Invalid opening"
        );
        require(
            Commitments.rootHistory[_tx.treeNumber][_tx.merkleRoot],
            "WithdrawFunds: Invalid Funds Merkle root"
        );
        require(
            !Commitments.nullifiers[_tx.treeNumber][_tx.nullifiers[0]],
            "WithdrawFunds: Invalid Funds first nullifier"
        );
        require(
            !Commitments.nullifiers[_tx.treeNumber][_tx.nullifiers[1]],
            "WithdrawFunds: Invalid Funds second nullifier"
        );
        require(
            Verifier.verifyJoinSplitProof(_tx),
            "WithdrawFunds: Invalid Funds proof"
        );

        uint256[] memory leaves = new uint256[](1);
        leaves[0] = _tx.commitments[1];
        Commitments.insertLeaves(leaves);

        Commitments.nullifiers[_tx.treeNumber][_tx.nullifiers[0]] = true;
        Commitments.nullifiers[_tx.treeNumber][_tx.nullifiers[1]] = true;

        payable(_recipient).transfer(_amount);
    }

    function withdrawNFT(
        uint256 _id,
        IERC721 _nftContract,
        address _recipient,
        OwnershipTransaction calldata _tx
    ) external {
        uint256 uid = uint256(
            keccak256(abi.encodePacked(_id, address(_nftContract)))
        ) % SNARK_SCALAR_FIELD;
        uint256 commitment = PoseidonT3.poseidon(
            [uid, uint256(uint160(_recipient))]
        );

        require(commitment == _tx.commitment, "WithdrawNFT: Invalid opening");

        require(
            Commitments.rootHistory[_tx.treeNumber][_tx.merkleRoot],
            "WithdrawNFT: Invalid NFT Merkle root"
        );

        require(
            !Commitments.nullifiers[_tx.treeNumber][_tx.nullifier],
            "WithdrawNFT: Invalid NFT  nullifier"
        );

        require(
            Verifier.verifyOwnershipProof(_tx),
            "WithdrawNFT: Invalid NFT proof"
        );

        Commitments.nullifiers[_tx.treeNumber][_tx.nullifier] = true;

        _nftContract.transferFrom(address(this), _recipient, _id);
    }

    function swap(
        JoinSplitTransaction calldata _js,
        OwnershipTransaction calldata _nft
    ) external {
        require(_js.message == _nft.commitment, "Swap: Invalid NFT transfer");
        require(
            _nft.message == _js.commitments[0],
            "Swap: Invalid Funds transfer"
        );

        require(
            Commitments.rootHistory[_js.treeNumber][_js.merkleRoot],
            "Swap: Invalid Funds Merkle root"
        );
        require(
            Commitments.rootHistory[_nft.treeNumber][_nft.merkleRoot],
            "Swap: Invalid NFT Merkle root"
        );

        require(
            !Commitments.nullifiers[_js.treeNumber][_js.nullifiers[0]],
            "Swap: Invalid Funds first nullifier"
        );
        require(
            !Commitments.nullifiers[_js.treeNumber][_js.nullifiers[1]],
            "Swap: Invalid Funds second nullifier"
        );
        require(
            !Commitments.nullifiers[_nft.treeNumber][_nft.nullifier],
            "Swap: Invalid NFT  nullifier"
        );

        require(
            Verifier.verifyJoinSplitProof(_js),
            "Swap: Invalid Funds proof"
        );
        require(Verifier.verifyOwnershipProof(_nft), "Swap: Invalid NFT proof");
        uint256[] memory leaves = new uint256[](3);
        leaves[0] = _js.commitments[0];
        leaves[1] = _js.commitments[1];
        leaves[2] = _nft.commitment;
        Commitments.insertLeaves(leaves);

        Commitments.nullifiers[_js.treeNumber][_js.nullifiers[0]] = true;
        Commitments.nullifiers[_js.treeNumber][_js.nullifiers[1]] = true;
        Commitments.nullifiers[_nft.treeNumber][_nft.nullifier] = true;
    }
}
