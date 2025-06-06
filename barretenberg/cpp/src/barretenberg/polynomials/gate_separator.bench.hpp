// === AUDIT STATUS ===
// internal:    { status: not started, auditors: [], date: YYYY-MM-DD }
// external_1:  { status: not started, auditors: [], date: YYYY-MM-DD }
// external_2:  { status: not started, auditors: [], date: YYYY-MM-DD }
// =====================

#include "barretenberg/ecc/curves/bn254/fr.hpp"
#include "barretenberg/polynomials/gate_separator.hpp"
#include <benchmark/benchmark.h>

using namespace benchmark;
using namespace bb;

namespace {

void compute_pow_poly(benchmark::State& state)
{
    // just set up huge vector
    std::vector<bb::fr> betas{ 1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14,
                               15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 };

    for (auto _ : state) {
        int64_t num_betas = state.range(0);
        std::vector<bb::fr> cur_betas(betas.begin(), betas.begin() + num_betas);
        GateSeparatorPolynomial poly{ cur_betas, cur_betas.size() };
    }
}

BENCHMARK(compute_pow_poly)->Unit(benchmark::kMillisecond)->Arg(20);

} // namespace
BENCHMARK_MAIN();