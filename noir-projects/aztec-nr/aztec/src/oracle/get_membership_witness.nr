use protocol_types::constants::{ARCHIVE_HEIGHT, NOTE_HASH_TREE_HEIGHT};

global NOTE_HASH_TREE_ID: Field = 1;
global ARCHIVE_TREE_ID: Field = 4;

// Note: We have M here because we need to somehow set it when calling get_membership_witness function and one way to
// do it is to set M here and then set type of the return param, e.g.:
//
// `let witness: MembershipWitness<NOTE_HASH_TREE_HEIGHT, NOTE_HASH_TREE_HEIGHT + 1> = get_membership_witness(...);`
//
// Another way to do it would be to add "type_hint: [Field; T]" as argument to `get_membership_witness` but that's
// a bit too boilerplatey for my taste.
pub struct MembershipWitness<let N: u32, let M: u32> {
    pub index: Field,
    pub path: [Field; N],
}

#[oracle(getMembershipWitness)]
unconstrained fn get_membership_witness<let N: u32, let M: u32>(
    _block_number: u32,
    _tree_id: Field,
    _leaf_value: Field,
) -> MembershipWitness<N, M> {}

// Note: get_nullifier_membership_witness function is implemented in get_nullifier_membership_witness.nr

pub unconstrained fn get_note_hash_membership_witness(
    block_number: u32,
    leaf_value: Field,
) -> MembershipWitness<NOTE_HASH_TREE_HEIGHT, NOTE_HASH_TREE_HEIGHT + 1> {
    get_membership_witness(block_number, NOTE_HASH_TREE_ID, leaf_value)
}

// There is no `get_public_data_membership_witness` function because it doesn't make sense to be getting a membership
// witness for a value in the public data tree.

pub unconstrained fn get_archive_membership_witness(
    block_number: u32,
    leaf_value: Field,
) -> MembershipWitness<ARCHIVE_HEIGHT, ARCHIVE_HEIGHT + 1> {
    get_membership_witness(block_number, ARCHIVE_TREE_ID, leaf_value)
}
