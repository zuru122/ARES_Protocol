// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

library SignatureAuth {
    bytes32 public constant APPROVAL_TYPEHASH =
        keccak256("Approval(bytes32 proposalId,address signer,uint256 nonce,uint256 deadline)");

    function getDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("ARES Protocol"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function getStructHash(bytes32 _proposalId, address _signer, uint256 _nonce, uint256 _deadline)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(APPROVAL_TYPEHASH, _proposalId, _signer, _nonce, _deadline));
    }

    function getDigest(bytes32 _proposalId, address _signer, uint256 _nonce, uint256 _deadline)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked("\x19\x01", getDomainSeparator(), getStructHash(_proposalId, _signer, _nonce, _deadline))
        );
    }

    function recoverSigner(
        bytes32 _proposalId,
        address _expectedSigner,
        uint256 _nonce,
        uint256 _deadline,
        bytes memory _signature
    ) internal view returns (address) {
        require(_signature.length == 65, "invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }

        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "invalid s value");

        require(v == 27 || v == 28, "invalid v value");

        bytes32 digest = getDigest(_proposalId, _expectedSigner, _nonce, _deadline);

        address recovered = ecrecover(digest, v, r, s);
        require(recovered != address(0), "invalid signature");

        return recovered;
    }

    function verifyThreshold(
        bytes32 _proposalId,
        address[] calldata _signers,
        bytes[] calldata _signatures,
        uint256[] calldata _signerNonces,
        uint256 _deadline,
        uint256 _threshold
    ) internal view returns (bool) {
        require(block.timestamp <= _deadline, "signatures expired");
        require(_signers.length == _signatures.length, "length mismatch");

        uint256 validCount = 0;

        for (uint256 i = 0; i < _signers.length; i++) {
            address recovered = recoverSigner(_proposalId, _signers[i], _signerNonces[i], _deadline, _signatures[i]);

            if (recovered == _signers[i]) {
                validCount++;
            }
        }

        return validCount >= _threshold;
    }
}
