// === AUDIT STATUS ===
// internal:    { status: not started, auditors: [], date: YYYY-MM-DD }
// external_1:  { status: not started, auditors: [], date: YYYY-MM-DD }
// external_2:  { status: not started, auditors: [], date: YYYY-MM-DD }
// =====================

#pragma once
#include "barretenberg/common/ref_array.hpp"
#include "barretenberg/ecc/curves/bn254/fr.hpp"
#include <array>

namespace bb {

/**
 * @brief Container for parameters used by the grand product (permutation, lookup) Honk relations
 *
 * @tparam T, either a native field type or a Univariate.
 */
template <typename T> struct RelationParameters {
    using DataType = T;
    static constexpr int NUM_BINARY_LIMBS_IN_GOBLIN_TRANSLATOR = 4;
    static constexpr int NUM_NATIVE_LIMBS_IN_GOBLIN_TRANSLATOR = 1;
    static constexpr int NUM_CHALLENGE_POWERS_IN_GOBLIN_TRANSLATOR = 4;
    static constexpr int NUM_TO_FOLD = 7;

    T eta{ 0 };                        // Lookup + Aux Memory
    T eta_two{ 0 };                    // Lookup + Aux Memory
    T eta_three{ 0 };                  // Lookup + Aux Memory
    T beta{ 0 };                       // Permutation + Lookup
    T gamma{ 0 };                      // Permutation + Lookup
    T public_input_delta{ 0 };         // Permutation
    T lookup_grand_product_delta{ 0 }; // Lookup
    T beta_sqr{ 0 };
    T beta_cube{ 0 };
    // eccvm_set_permutation_delta is used in the set membership gadget in eccvm/ecc_set_relation.hpp
    // We can remove this by modifying the relation, but increases complexity
    T eccvm_set_permutation_delta = T(0);
    std::array<T, NUM_BINARY_LIMBS_IN_GOBLIN_TRANSLATOR> accumulated_result = { T(0), T(0), T(0), T(0) }; // Translator
    std::array<T, NUM_BINARY_LIMBS_IN_GOBLIN_TRANSLATOR + NUM_NATIVE_LIMBS_IN_GOBLIN_TRANSLATOR> evaluation_input_x = {
        T(0), T(0), T(0), T(0), T(0)
    }; // Translator
    std::array<std::array<T, NUM_BINARY_LIMBS_IN_GOBLIN_TRANSLATOR + NUM_NATIVE_LIMBS_IN_GOBLIN_TRANSLATOR>,
               NUM_CHALLENGE_POWERS_IN_GOBLIN_TRANSLATOR>
        batching_challenge_v = { { { T(0), T(0), T(0), T(0), T(0) },
                                   { T(0), T(0), T(0), T(0), T(0) },
                                   { T(0), T(0), T(0), T(0), T(0) },
                                   { T(0), T(0), T(0), T(0), T(0) } } };

    RefArray<T, NUM_TO_FOLD> get_to_fold()
    {
        return RefArray{ eta, eta_two, eta_three, beta, gamma, public_input_delta, lookup_grand_product_delta };
    }

    RefArray<const T, NUM_TO_FOLD> get_to_fold() const
    {
        return RefArray{ eta, eta_two, eta_three, beta, gamma, public_input_delta, lookup_grand_product_delta };
    }

    static RelationParameters get_random()
    {
        RelationParameters result;
        result.eta = T::random_element();
        result.eta_two = T::random_element();
        result.eta_three = T::random_element();
        result.beta = T::random_element();
        result.beta_sqr = result.beta * result.beta;
        result.beta_cube = result.beta_sqr * result.beta;
        result.gamma = T::random_element();
        result.public_input_delta = T::random_element();
        result.lookup_grand_product_delta = T::random_element();
        result.eccvm_set_permutation_delta = result.gamma * (result.gamma + result.beta_sqr) *
                                             (result.gamma + result.beta_sqr + result.beta_sqr) *
                                             (result.gamma + result.beta_sqr + result.beta_sqr + result.beta_sqr);
        result.accumulated_result = {
            T::random_element(), T::random_element(), T::random_element(), T::random_element()
        };

        result.evaluation_input_x = {
            T::random_element(), T::random_element(), T::random_element(), T::random_element(), T::random_element()
        };
        result.batching_challenge_v = {
            std::array{ T::random_element(),
                        T::random_element(),
                        T::random_element(),
                        T::random_element(),
                        T::random_element() },
            { T::random_element(), T::random_element(), T::random_element(), T::random_element(), T::random_element() },
            { T::random_element(), T::random_element(), T::random_element(), T::random_element(), T::random_element() },
            { T::random_element(), T::random_element(), T::random_element(), T::random_element(), T::random_element() },
        };

        return result;
    }

    MSGPACK_FIELDS(eta, eta_two, eta_three, beta, gamma, public_input_delta, lookup_grand_product_delta);
};
} // namespace bb
