// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma abicoder v2;

import {SnarkProof, G1Point, VerifyingKey, OwnershipTransaction, JoinSplitTransaction, SNARK_SCALAR_FIELD} from "./Globals.sol";

import {Snark} from "./Snark.sol";

contract Verifier {
    VerifyingKey[2] internal vKeys;

    function initializeVerifier(VerifyingKey[2] calldata _vKeys) internal {
        for (uint256 i = 0; i < _vKeys.length; i++) {
            // Alpha
            vKeys[i].alpha1.x = _vKeys[i].alpha1.x;
            vKeys[i].alpha1.y = _vKeys[i].alpha1.y;
            for (uint256 j = 0; j < 2; j++) {
                // Beta
                vKeys[i].beta2.x[j] = _vKeys[i].beta2.x[j];
                vKeys[i].beta2.y[j] = _vKeys[i].beta2.y[j];
                // Gamma
                vKeys[i].gamma2.x[j] = _vKeys[i].gamma2.x[j];
                vKeys[i].gamma2.y[j] = _vKeys[i].gamma2.y[j];
                // Delta
                vKeys[i].delta2.x[j] = _vKeys[i].delta2.x[j];
                vKeys[i].delta2.y[j] = _vKeys[i].delta2.y[j];
            }
            for (uint8 j = 0; j < _vKeys[i].ic.length; j++) {
                // IC
                vKeys[i].ic.push(G1Point(_vKeys[i].ic[j].x, _vKeys[i].ic[j].y));
            }
        }
    }

    function verifyJoinSplitProof(
        JoinSplitTransaction calldata _tx
    ) public view returns (bool) {
        uint256[] memory inputs = new uint256[](6);
        inputs[0] = _tx.message;
        inputs[1] = _tx.merkleRoot;
        inputs[2] = _tx.nullifiers[0];
        inputs[3] = _tx.nullifiers[1];
        inputs[4] = _tx.commitments[0];
        inputs[5] = _tx.commitments[1];
        return Snark.verify(vKeys[0], _tx.proof, inputs);
    }

    function verifyOwnershipProof(
        OwnershipTransaction calldata _tx
    ) public view returns (bool) {
        uint256[] memory inputs = new uint256[](4);
        inputs[0] = _tx.message;
        inputs[1] = _tx.merkleRoot;
        inputs[2] = _tx.nullifier;
        inputs[3] = _tx.commitment;
        return Snark.verify(vKeys[1], _tx.proof, inputs);
    }
}
