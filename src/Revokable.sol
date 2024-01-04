// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.23;

// For questions, comments, and feedback, find me at https://grin.io

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

abstract contract Revokable is Context {
    address private _revoker;

    error MustBeRevoker(address account);
    error InvalidRevoker(address account);

    event RevokerChanged(
        address indexed previousRevoker,
        address indexed newRevoker
    );

    constructor(address initialRevoker) {
        if (initialRevoker == address(0)) {
            revert InvalidRevoker(address(0));
        }
        _changeRevoker(initialRevoker);
    }

    modifier onlyRevoker() {
        if (revoker() != _msgSender()) {
            revert MustBeRevoker(_msgSender());
        }
        _;
    }

    function revoker() public view returns (address) {
        return _revoker;
    }

    function isRevokable() public view returns (bool) {
        return _revoker != address(0);
    }

    function changeRevoker(address newRevoker) public onlyRevoker {
        if (newRevoker == address(0)) {
            revert InvalidRevoker(newRevoker);
        }
        _changeRevoker(newRevoker);
    }

    function _changeRevoker(address newRevoker) internal {
        address oldRevoker = _revoker;
        _revoker = newRevoker;
        emit RevokerChanged(oldRevoker, newRevoker);
    }

    function renounceRevokability() public onlyRevoker {
        _changeRevoker(address(0));
    }

    function revoke() public virtual onlyRevoker {
        _revoke();
    }

    function _revoke() internal virtual;

    function revoke(address token) public virtual onlyRevoker {
        _revoke(token);
    }

    function _revoke(address token) internal virtual;
}
