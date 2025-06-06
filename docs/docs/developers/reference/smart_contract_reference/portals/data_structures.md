---
title: Data Structures
---

The `DataStructures` are structs that we are using throughout the message infrastructure and registry.

**Links**: [Implementation (GitHub link)](https://github.com/AztecProtocol/aztec-packages/blob/master/l1-contracts/src/core/libraries/DataStructures.sol).

## `L1Actor`

An entity on L1, specifying the address and the chainId for the entity. Used when specifying sender/recipient with an entity that is on L1.

#include_code l1_actor l1-contracts/src/core/libraries/DataStructures.sol solidity

| Name           | Type    | Description |
| -------------- | ------- | ----------- |
| `actor`          | `address` | The L1 address of the actor |
| `chainId`        | `uint256` | The chainId of the actor. Defines the blockchain that the actor lives on. |


## `L2Actor`

An entity on L2, specifying the address and the version for the entity. Used when specifying sender/recipient with an entity that is on L2.

#include_code l2_actor l1-contracts/src/core/libraries/DataStructures.sol solidity

| Name           | Type    | Description |
| -------------- | ------- | ----------- |
| `actor`          | `bytes32` | The aztec address of the actor. |
| `version`        | `uint256` | The version of Aztec that the actor lives on. |

## `L1ToL2Message`

A message that is sent from L1 to L2.

#include_code l1_to_l2_msg l1-contracts/src/core/libraries/DataStructures.sol solidity

| Name           | Type    | Description |
| -------------- | ------- | ----------- |
| `sender`          | `L1Actor` | The actor on L1 that is sending the message. |
| `recipient`        | `L2Actor` | The actor on L2 that is to receive the message. |
| `content`        | `field (~254 bits)` | The field element containing the content to be sent to L2. |
| `secretHash`        | `field (~254 bits)` | The hash of a secret pre-image that must be known to consume the message on L2. Use [`computeSecretHash` (GitHub link)](https://github.com/AztecProtocol/aztec-packages/blob/master/yarn-project/aztec.js/src/utils/secrets.ts) to compute it from a secret. |

## `L2ToL1Message`

A message that is sent from L2 to L1.

#include_code l2_to_l1_msg l1-contracts/src/core/libraries/DataStructures.sol solidity

| Name           | Type    | Description |
| -------------- | ------- | ----------- |
| `sender`          | `L2Actor` | The actor on L2 that is sending the message. |
| `recipient`        | `L1Actor` | The actor on L1 that is to receive the message. |
| `content`        | `field (~254 bits)` | The field element containing the content to be consumed by the portal on L1. |


