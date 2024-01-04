// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

// For questions, comments, and feedback, find me at https://grin.io

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Impletments ERC-1271 for Ownable contracts such that signaters by the owner are valid.
 * @dev See https://eips.ethereum.org/EIPS/eip-1271
 */
abstract contract OwnerSignable is Ownable {
    /**
     * @notice Verifies that the signer is the owner of the signing contract.
     */
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view virtual returns (bytes4) {
        // Validate signatures
        if (recoverSigner(_hash, _signature) == owner()) {
            return 0x1626ba7e;
        } else {
            return 0xffffffff;
        }
    }

    function toBytes32(
        bytes memory _bytes,
        uint256 start
    ) internal pure returns (bytes32) {
        bytes32 tempBytes32;

        assembly {
            tempBytes32 := mload(add(add(_bytes, 32), start))
        }

        return tempBytes32;
    }

    /**
     * @notice Recover the signer of hash, assuming it's an EOA account
     * @dev Only for EthSign signatures
     * @param _hash       Hash of message that was signed
     * @param _signature  Signature encoded as (bytes32 r, bytes32 s, uint8 v)
     */
    function recoverSigner(
        bytes32 _hash,
        bytes memory _signature
    ) internal pure returns (address signer) {
        require(
            _signature.length == 65,
            "SignatureValidator#recoverSigner: invalid signature length"
        );

        // Variables are not scoped in Solidity.
        uint8 v = uint8(_signature[64]);
        bytes32 r = toBytes32(_signature, 0);
        bytes32 s = toBytes32(_signature, 32);

        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        //
        // Source OpenZeppelin
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/cryptography/ECDSA.sol

        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) {
            revert(
                "SignatureValidator#recoverSigner: invalid signature 's' value"
            );
        }

        if (v != 27 && v != 28) {
            revert(
                "SignatureValidator#recoverSigner: invalid signature 'v' value"
            );
        }

        // Recover ECDSA signer
        signer = ecrecover(_hash, v, r, s);

        // Prevent signer from being 0x0
        require(
            signer != address(0x0),
            "SignatureValidator#recoverSigner: INVALID_SIGNER"
        );

        return signer;
    }
}
