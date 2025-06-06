// === AUDIT STATUS ===
// internal:    { status: not started, auditors: [], date: YYYY-MM-DD }
// external_1:  { status: not started, auditors: [], date: YYYY-MM-DD }
// external_2:  { status: not started, auditors: [], date: YYYY-MM-DD }
// =====================

#pragma once
#include "barretenberg/goblin/translation_evaluations.hpp"
#include "barretenberg/honk/proof_system/types/proof.hpp"
#include "barretenberg/translator_vm/translator_flavor.hpp"
#include "barretenberg/translator_vm/translator_prover.hpp"

namespace bb {
class TranslatorVerifier {
  public:
    using Flavor = TranslatorFlavor;
    using FF = typename Flavor::FF;
    using BF = typename Flavor::BF;
    using Commitment = typename Flavor::Commitment;
    using ProvingKey = typename Flavor::ProvingKey;
    using VerificationKey = typename Flavor::VerificationKey;
    using VerifierCommitmentKey = typename Flavor::VerifierCommitmentKey;
    using TranslationEvaluations = bb::TranslationEvaluations_<BF>;
    using Transcript = typename Flavor::Transcript;

    BF evaluation_input_x = 0;
    BF batching_challenge_v = 0;

    // Default construct fixed VK
    std::shared_ptr<VerificationKey> key = std::make_shared<VerificationKey>();
    std::map<std::string, Commitment> commitments;
    std::shared_ptr<Transcript> transcript;
    RelationParameters<FF> relation_parameters;

    TranslatorVerifier(const std::shared_ptr<Transcript>& transcript);

    TranslatorVerifier(const std::shared_ptr<VerificationKey>& verifier_key,
                       const std::shared_ptr<Transcript>& transcript);

    TranslatorVerifier(const std::shared_ptr<ProvingKey>& proving_key, const std::shared_ptr<Transcript>& transcript);

    void put_translation_data_in_relation_parameters(const uint256_t& evaluation_input_x,
                                                     const BF& batching_challenge_v,
                                                     const uint256_t& accumulated_result);
    bool verify_proof(const HonkProof& proof, const uint256_t& evaluation_input_x, const BF& batching_challenge_v);
    bool verify_translation(const TranslationEvaluations& translation_evaluations,
                            const BF& translation_masking_term_eval);
};
} // namespace bb
