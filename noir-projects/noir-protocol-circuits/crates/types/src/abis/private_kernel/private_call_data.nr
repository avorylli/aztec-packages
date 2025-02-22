use crate::{
    abis::{
        private_circuit_public_inputs::PrivateCircuitPublicInputs,
        protocol_contract_leaf_preimage::ProtocolContractLeafPreimage,
    },
    address::SaltedInitializationHash,
    constants::{
        FUNCTION_TREE_HEIGHT, PROOF_TYPE_OINK, PROOF_TYPE_PG, PROTOCOL_CONTRACT_TREE_HEIGHT,
    },
    merkle_tree::membership::MembershipWitness,
    proof::verification_key::ClientIVCVerificationKey,
    public_keys::PublicKeys,
};

pub struct PrivateCallData {
    pub public_inputs: PrivateCircuitPublicInputs,

    pub vk: ClientIVCVerificationKey,

    pub salted_initialization_hash: SaltedInitializationHash,
    pub public_keys: PublicKeys,
    pub contract_class_artifact_hash: Field,
    pub contract_class_public_bytecode_commitment: Field,
    pub function_leaf_membership_witness: MembershipWitness<FUNCTION_TREE_HEIGHT>,
    pub protocol_contract_membership_witness: MembershipWitness<PROTOCOL_CONTRACT_TREE_HEIGHT>,
    pub protocol_contract_leaf: ProtocolContractLeafPreimage,
    pub acir_hash: Field,
}

impl PrivateCallData {
    pub fn verify(self, is_first_app: bool) {
        let proof_type = if is_first_app {
            PROOF_TYPE_OINK
        } else {
            PROOF_TYPE_PG
        };
        // Client IVC public inputs are linked in the backend via the databus
        std::verify_proof_with_type(self.vk.key, [], [], 0, proof_type);
    }
}

pub struct PrivateCallDataWithoutPublicInputs {
    pub vk: ClientIVCVerificationKey,

    pub salted_initialization_hash: SaltedInitializationHash,
    pub public_keys: PublicKeys,
    pub contract_class_artifact_hash: Field,
    pub contract_class_public_bytecode_commitment: Field,
    pub function_leaf_membership_witness: MembershipWitness<FUNCTION_TREE_HEIGHT>,
    pub protocol_contract_membership_witness: MembershipWitness<PROTOCOL_CONTRACT_TREE_HEIGHT>,
    pub protocol_contract_leaf: ProtocolContractLeafPreimage,
    pub acir_hash: Field,
}

impl PrivateCallDataWithoutPublicInputs {
    pub fn to_private_call_data(
        self,
        public_inputs: PrivateCircuitPublicInputs,
    ) -> PrivateCallData {
        PrivateCallData {
            public_inputs,
            vk: self.vk,
            salted_initialization_hash: self.salted_initialization_hash,
            public_keys: self.public_keys,
            contract_class_artifact_hash: self.contract_class_artifact_hash,
            contract_class_public_bytecode_commitment: self
                .contract_class_public_bytecode_commitment,
            function_leaf_membership_witness: self.function_leaf_membership_witness,
            protocol_contract_membership_witness: self.protocol_contract_membership_witness,
            protocol_contract_leaf: self.protocol_contract_leaf,
            acir_hash: self.acir_hash,
        }
    }
}
