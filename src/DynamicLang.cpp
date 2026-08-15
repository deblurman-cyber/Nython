// DynamicLang.cpp
// Provides the single definition of DynamicLangRegistry::instance()
// so all translation units share ONE registry object (ODR-safe).
// ──────────────────────────────────────────────────────────────────
#include "DynamicLang.hpp"

namespace nython {

// Explicit out-of-line instantiation so the linker sees exactly one definition.
// All TUs that include DynamicLang.hpp will call this function and get the
// same static object.
DynamicLangRegistry& DynamicLangRegistry::instance() {
    static DynamicLangRegistry reg;
    return reg;
}

} // namespace nython
