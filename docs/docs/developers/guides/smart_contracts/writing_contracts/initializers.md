---
title: Defining Initializer Functions
sidebar_position: 1
tags: [functions, contracts]
---

This page explains how to write an initializer function, also known as a constructor.

Initializers are regular functions that set an "initialized" flag (a nullifier) for the contract. A contract can only be initialized once, and contract functions can only be called after the contract has been initialized, much like a constructor. However, if a contract defines no initializers, it can be called at any time. Additionally, you can define as many initializer functions in a contract as you want, both private and public.

## Annotate with `#[initializer]`

Define your initializer like so:

```rust
#[initializer]
fn constructor(){
    // function logic here
}
```

## Public or private

Aztec supports both public and private initializers. Use the appropriate macro, for example for a private initializer:

```rust
#[private]
#[initializer]
fn constructor(){
    // function logic here
}
```

## Initializer with logic

Initializers are commonly used to set an admin, such as this example:

#include_code constructor /noir-projects/noir-contracts/contracts/app/token_contract/src/main.nr rust

Here, the initializer is writing to storage. It can also call another function. Learn more about calling functions from functions [here](./call_contracts.md).

## Multiple initializers

You can set multiple functions as an initializer function simply by annotating each of them with `#[initializer]`. You can then decide which one to call when you are deploying the contract.

Calling any one of the functions annotated with `#[initializer]` will mark the contract as initialized.

To see an initializer in action, follow the [Counter codealong tutorial](../../../tutorials/codealong/contract_tutorials/counter_contract.md).
