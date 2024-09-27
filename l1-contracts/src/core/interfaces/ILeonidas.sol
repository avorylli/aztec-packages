// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

import {Timestamp, Slot, Epoch} from "@aztec/core/libraries/TimeMath.sol";

interface ILeonidas {
  // Changing depending on sybil mechanism and slashing enforcement
  function addValidator(address _validator) external;
  function removeValidator(address _validator) external;

  // Likely changing to optimize in Pleistarchus
  function setupEpoch() external;
  function getCurrentProposer() external view returns (address);
  function getProposerAt(Timestamp _ts) external view returns (address);

  // Stable
  function getCurrentEpoch() external view returns (Epoch);
  function getCurrentSlot() external view returns (Slot);
  function isValidator(address _validator) external view returns (bool);
  function getValidatorCount() external view returns (uint256);
  function getValidatorAt(uint256 _index) external view returns (address);

  // Consider removing below this point
  function getTimestampForSlot(Slot _slotNumber) external view returns (Timestamp);

  // Likely removal of these to replace with a size and indiviual getter
  // Get the current epoch committee
  function getCurrentEpochCommittee() external view returns (address[] memory);
  function getEpochCommittee(Epoch _epoch) external view returns (address[] memory);
  function getValidators() external view returns (address[] memory);

  function getEpochAt(Timestamp _ts) external view returns (Epoch);
  function getSlotAt(Timestamp _ts) external view returns (Slot);
}