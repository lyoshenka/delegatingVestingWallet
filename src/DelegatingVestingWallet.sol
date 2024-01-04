// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

// For questions, comments, and feedback, find me at https://grin.io

import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";
// import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";

import {Revokable} from "./Revokable.sol";

/**
 * @dev Interface for gnosis DelegateRegistry used by snapshot
 *
 * docs: https://docs.snapshot.org/user-guides/delegation#delegation-contract
 * snapshot contract: https://etherscan.io/address/0x469788fE6E9E9681C6ebF3bF78e7Fd26Fc015446#code
 */
interface IDelegation {
    function setDelegate(bytes32 id, address delegate) external;

    function clearDelegate(bytes32 id) external;
}

/**
 * @dev This contract extends the VestingWallet contract to allow:
 *
 * - a cliff period before vesting kicks in
 * - acceleration of vesting
 * - revocation of unvested ether and tokens
 * - delegating tokens for voting on proposals (e.g. on snapshot)
 */
contract DelegatingVestingWallet is VestingWallet, Revokable {
    event EtherRevoked(uint256 amount);
    event ERC20Revoked(address indexed token, uint256 amount);
    event Accelerated();

    uint64 private immutable _cliff; // how many seconds from start until cliff
    bool private _accelerated;

    constructor(
        address beneficiary,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffDurationSeconds
    )
        VestingWallet(beneficiary, startTimestamp, durationSeconds)
        Revokable(msg.sender)
    {
        _cliff = cliffDurationSeconds;
    }

    modifier onlyBeneficiary() {
        _checkOwner();
        _;
    }

    /**
     * @dev The cliff is the period at the start of the vesting schedule where
     * nothing is vested. At the end of the cliff, all the tokens that should
     * have vested so far vest at once.
     *
     * As an example, if you have a 4 year linear vest and a 1 year cliff, then:
     *  - no tokens vest during the first year
     *  - at the end of the first year, 25% of the tokens vest all at once
     */
    function cliff() public view returns (uint256) {
        return _cliff;
    }

    function cliffEnd() public view returns (uint256) {
        return start() + cliff();
    }

    function isPastCliff() public view returns (bool) {
        return block.timestamp >= cliffEnd();
    }

    /**
     * @dev Accelerate vesting, which immediately vests all ether and tokens
     */
    function accelerate() public onlyRevoker {
        emit Accelerated();
        _accelerated = true;
    }

    function isAccelerated() public view returns (bool) {
        return _accelerated;
    }

    /**
     * @dev Calculate amount of ether that can be revoked
     *
     * You can revoke ether that's not vested yet.
     *
     * released() should always be >= vestedAmount(), so this
     * function should never return a negative number.
     *
     */
    function revokableAmount() public view returns (uint256) {
        if (!isRevokable() || isAccelerated()) {
            return 0;
        }
        return
            address(this).balance +
            released() -
            vestedAmount(uint64(block.timestamp));
    }

    /**
     * @dev Calculate amount of `token` tokens that can be revoked. `token` should be
     * the address of an IERC20 contract.
     */
    function revokableAmount(address token) public view returns (uint256) {
        if (!isRevokable() || isAccelerated()) {
            return 0;
        }
        return
            IERC20(token).balanceOf(address(this)) +
            released(token) -
            vestedAmount(token, uint64(block.timestamp));
    }

    /**
     * @dev Return unvested ether
     *
     * Emits a {EtherRevoked} event.
     */
    function _revoke() internal override {
        uint256 amount = revokableAmount();
        emit EtherRevoked(amount);
        Address.sendValue(payable(revoker()), amount);
    }

    /**
     * @dev Return unvested `token` tokens. `token` should be the address of an
     * IERC20 contract.
     *
     * Emits a {ERC20Revoked} event.
     */
    function _revoke(address token) internal override {
        uint256 amount = revokableAmount(token);
        emit ERC20Revoked(token, amount);
        SafeERC20.safeTransfer(IERC20(token), revoker(), amount);
    }

    /**
     * @dev Override vesting schedule to add cliff
     */
    function _vestingSchedule(
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view override returns (uint256) {
        if (!isPastCliff()) {
            return 0;
        } else if (isAccelerated()) {
            return totalAllocation;
        }
        return super._vestingSchedule(totalAllocation, timestamp);
    }

    /**
     * @dev Override so only owner can release tokens
     */
    function release(address token) public override onlyBeneficiary {
        super.release(token);
    }

    /**
     * @dev Delegate tokens for voting
     */
    function setDelegate(
        address delegateContract,
        address delegate
    ) external onlyBeneficiary {
        IDelegation(delegateContract).setDelegate("", delegate);
    }

    // copied these from Arbitrum, not sure what they do

    // function delegate(address token, address delegatee) external onlyBeneficiary {
    //     IVotes(token).delegate(delegatee);
    // }

    // function castVote(address governor, uint256 proposalId, uint8 support) external onlyBeneficiary {
    //     IGovernor(governor).castVote(proposalId, support);
    // }
}
