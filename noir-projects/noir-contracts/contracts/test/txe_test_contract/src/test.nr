use crate::TXETest;

use dep::aztec::{prelude::AztecAddress, test::helpers::test_environment::TestEnvironment};

use aztec::macros::functions::initializer;
use easy_private_state::EasyPrivateUint;
use value_note::{balance_utils, value_note::ValueNote};

use crate::test;
use dep::aztec::note::note_getter::{MAX_NOTES_PER_PAGE, view_notes};
use dep::aztec::note::note_viewer_options::NoteViewerOptions;
use dep::aztec::protocol_types::storage::map::derive_storage_slot_in_map;

pub unconstrained fn setup(
    initial_value: Field,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    // Setup env, generate keys
    let mut env = TestEnvironment::_new();
    let owner = env.create_account(1);
    let sender = env.create_account(2);
    env.impersonate(owner);

    // Deploy contract and initialize
    let initializer = TXETest::interface().initialize(initial_value as u64, owner);
    let counter_contract = env.deploy_self("TXETest").with_private_initializer(initializer);
    let contract_address = counter_contract.to_address();
    (&mut env, contract_address, owner, sender)
}

#[test]
unconstrained fn new_calling_flow_increment_self_and_other() {
    let mut env = TestEnvironment::new();
    let owner = env.create_account(1);
    let sender = env.create_account(2);
    let third = env.create_account(3);

    env.impersonate(owner);

    let initial_value: Field = 2;
    let initializer = TXETest::interface().initialize(initial_value as u64, owner);
    let counter_contract = env.deploy_self("TXETest").with_private_initializer(initializer);
    let contract_address = counter_contract.to_address();

    let initializer2 = TXETest::interface().initialize(initial_value as u64, third);
    let counter_contract2 = env.deploy_self("TXETest").with_private_initializer(initializer2);
    let contract_address2 = counter_contract2.to_address();

    let _ = env.call_private_void(
        owner,
        TXETest::at(contract_address).increment_self_and_other(contract_address2, owner, sender),
    );

    env.impersonate(contract_address);

    TXETest::sync_notes();
    let mut options = NoteViewerOptions::new();
    let counter_slot = TXETest::storage_layout().counters.slot;

    let owner_storage_slot = derive_storage_slot_in_map(counter_slot, owner);
    let notes: BoundedVec<ValueNote, MAX_NOTES_PER_PAGE> = view_notes(owner_storage_slot, options);

    let current_value_for_owner = TXETest::get_counter(owner);

    assert_eq(notes.len(), 2);
    assert_eq(current_value_for_owner, 3);

    env.impersonate(contract_address2);

    TXETest::sync_notes();
    let counter_slot = TXETest::storage_layout().counters.slot;

    let owner_storage_slot = derive_storage_slot_in_map(counter_slot, owner);
    let notes: BoundedVec<ValueNote, MAX_NOTES_PER_PAGE> = view_notes(owner_storage_slot, options);

    let current_value_for_owner = TXETest::get_counter(owner);

    assert_eq(notes.len(), 1);
    assert_eq(current_value_for_owner, 1);
}

#[test]
unconstrained fn new_calling_flow_increment_with_new_call_flow() {
    let mut env = TestEnvironment::new();
    let owner = env.create_account(1);
    let sender = env.create_account(2);
    env.impersonate(owner);

    let initial_value: Field = 2;
    let initializer = TXETest::interface().initialize(initial_value as u64, owner);
    let counter_contract = env.deploy_self("TXETest").with_private_initializer(initializer);
    let contract_address = counter_contract.to_address();

    let _ = env.call_private_void(owner, TXETest::at(contract_address).increment(owner, sender));

    env.impersonate(contract_address);

    TXETest::sync_notes();
    let mut options = NoteViewerOptions::new();
    let counter_slot = TXETest::storage_layout().counters.slot;

    let owner_storage_slot = derive_storage_slot_in_map(counter_slot, owner);
    let notes: BoundedVec<ValueNote, MAX_NOTES_PER_PAGE> = view_notes(owner_storage_slot, options);

    let current_value_for_owner = TXETest::get_counter(owner);

    assert_eq(notes.len(), 2);
    assert_eq(current_value_for_owner, 3);
}
