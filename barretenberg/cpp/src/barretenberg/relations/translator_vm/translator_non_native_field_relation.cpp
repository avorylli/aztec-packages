// === AUDIT STATUS ===
// internal:    { status: not started, auditors: [], date: YYYY-MM-DD }
// external_1:  { status: not started, auditors: [], date: YYYY-MM-DD }
// external_2:  { status: not started, auditors: [], date: YYYY-MM-DD }
// =====================

#include "barretenberg/relations/translator_vm/translator_non_native_field_relation_impl.hpp"
#include "barretenberg/translator_vm/translator_flavor.hpp"
namespace bb {
template class TranslatorNonNativeFieldRelationImpl<fr>;
DEFINE_SUMCHECK_RELATION_CLASS(TranslatorNonNativeFieldRelationImpl, TranslatorFlavor);
} // namespace bb