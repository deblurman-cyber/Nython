// DynamicLang.hpp — Runtime-extensible language system for Nython
// Shared singleton registry consulted by Lexer, Parser and Executor.
// Users extend the language at runtime via lang_* builtins.
// ─────────────────────────────────────────────────────────────────
#pragma once
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmisleading-indentation"
#include <string>
#include <vector>
#include <unordered_map>
#include <regex>
#include <mutex>
#include <algorithm>

namespace nython {

// ── DynamicToken ─────────────────────────────────────────────────
// A new keyword (word-boundary, identifier-like) registered at
// runtime. When the lexer sees this word it tags the token with
// prefix "__dyntok:<id>:<word>" so the parser can route it.
struct DynamicToken {
    std::string name;        // e.g. "emit", "unless", "repeat_n"
    std::string pattern;     // regex override (empty = exact match)
    std::string category;    // "keyword" | "operator" | "literal"
    std::string description;
    int         token_id = -1; // assigned on registration
};

// ── DynamicRule ───────────────────────────────────────────────────
// Rules change what a dynamic keyword (or any source text) means.
//
//  REWRITE   – regex substitution applied to source BEFORE lexing.
//              pattern/expansion are ECMAScript regexes.
//  MACRO     – triggered when parser sees trigger_token (a dynamic
//              keyword). Remaining tokens to EOL become string args
//              passed to the Nython handler function.
//  INFIX_OP  – trigger_token acts as a binary operator between two
//              expressions; handler(lhs, rhs) is called at runtime.
//  PREFIX_OP – trigger_token acts as a prefix operator; handler(rhs).
struct DynamicRule {
    std::string name;
    enum class Kind { REWRITE, MACRO, INFIX_OP, PREFIX_OP } kind;
    std::string trigger_token; // dynamic keyword name that fires this
    std::string pattern;       // REWRITE: ECMAScript regex source pattern
    std::string expansion;     // REWRITE: replacement string
    int         precedence = 50; // INFIX_OP: relative to other operators
    bool        right_assoc = false;
    std::string description;
    void*       handler_value = nullptr; // points to heap-allocated Value*
};

// ── DynamicOperator ───────────────────────────────────────────────
// A purely-symbolic operator (non-identifier chars) like <~>, ??, >>>.
// The lexer recognises it in the default: branch and tags it
// "__dynop:<symbol>".
struct DynamicOperator {
    std::string symbol;      // e.g. "??", "<~>", ">>>"
    enum class Arity { PREFIX, INFIX, POSTFIX } arity;
    int  precedence = 50;
    bool right_assoc = false;
    std::string description;
    void* handler_value = nullptr;
};

// ── DynamicLangRegistry ───────────────────────────────────────────
class DynamicLangRegistry {
public:
    static DynamicLangRegistry& instance(); // defined in DynamicLang.cpp (ODR-safe)

    // ── tokens ────────────────────────────────────────────────────
    int add_token(DynamicToken tok) {
        std::lock_guard<std::mutex> lk(mtx_);
        auto it = tmap_.find(tok.name);
        if (it != tmap_.end()) return it->second;
        tok.token_id = (int)tokens_.size();
        tmap_[tok.name] = tok.token_id;
        tokens_.push_back(std::move(tok));
        ver_++;
        return tokens_.back().token_id;
    }
    bool remove_token(const std::string& name) {
        std::lock_guard<std::mutex> lk(mtx_);
        auto it = tmap_.find(name);
        if (it == tmap_.end()) return false;
        tokens_[it->second].name = "";
        tmap_.erase(it);
        ver_++;
        return true;
    }
    const DynamicToken* find_token(const std::string& name) const {
        auto it = tmap_.find(name);
        return (it == tmap_.end()) ? nullptr : &tokens_[it->second];
    }
    const std::vector<DynamicToken>& tokens() const { return tokens_; }

    // ── rules ────────────────────────────────────────────────────
    int add_rule(DynamicRule r) {
        std::lock_guard<std::mutex> lk(mtx_);
        for (size_t i = 0; i < rules_.size(); i++)
            if (rules_[i].name == r.name) { rules_[i] = r; ver_++; return (int)i; }
        rules_.push_back(std::move(r));
        ver_++;
        return (int)rules_.size()-1;
    }
    bool remove_rule(const std::string& name) {
        std::lock_guard<std::mutex> lk(mtx_);
        for (auto it = rules_.begin(); it != rules_.end(); ++it)
            if (it->name == name) { rules_.erase(it); ver_++; return true; }
        return false;
    }
    // Find all rules for a trigger token name
    std::vector<const DynamicRule*> rules_for(const std::string& trigger) const {
        std::vector<const DynamicRule*> out;
        for (auto& r : rules_)
            if (r.trigger_token == trigger) out.push_back(&r);
        return out;
    }
    // Find highest-priority INFIX_OP rule for a trigger token
    const DynamicRule* infix_rule_for(const std::string& trigger) const {
        for (auto& r : rules_)
            if (r.trigger_token == trigger && r.kind == DynamicRule::Kind::INFIX_OP) return &r;
        return nullptr;
    }
    const DynamicRule* prefix_rule_for(const std::string& trigger) const {
        for (auto& r : rules_)
            if (r.trigger_token == trigger && r.kind == DynamicRule::Kind::PREFIX_OP) return &r;
        return nullptr;
    }
    const DynamicRule* macro_rule_for(const std::string& trigger) const {
        for (auto& r : rules_)
            if (r.trigger_token == trigger && r.kind == DynamicRule::Kind::MACRO) return &r;
        return nullptr;
    }
    const std::vector<DynamicRule>& rules() const { return rules_; }

    // ── operators ─────────────────────────────────────────────────
    int add_operator(DynamicOperator op) {
        std::lock_guard<std::mutex> lk(mtx_);
        for (size_t i = 0; i < ops_.size(); i++)
            if (ops_[i].symbol == op.symbol) { ops_[i] = op; ver_++; return (int)i; }
        // Keep sorted by symbol length desc for greedy match
        ops_.push_back(std::move(op));
        std::stable_sort(ops_.begin(), ops_.end(),
            [](const DynamicOperator& a, const DynamicOperator& b){
                return a.symbol.size() > b.symbol.size();
            });
        ver_++;
        return (int)ops_.size()-1;
    }
    bool remove_operator(const std::string& sym) {
        std::lock_guard<std::mutex> lk(mtx_);
        for (auto it = ops_.begin(); it != ops_.end(); ++it)
            if (it->symbol == sym) { ops_.erase(it); ver_++; return true; }
        return false;
    }
    DynamicOperator* find_operator(const std::string& sym) {
        for (auto& op : ops_) if (op.symbol == sym) return &op;
        return nullptr;
    }
    const std::vector<DynamicOperator>& operators() const { return ops_; }

    // ── source pre-processing (REWRITE rules) ────────────────────
    // Call before lexing any source string. Applies all REWRITE rules
    // as regex substitutions in registration order.
    // Convert legacy \1..\9 backreferences to $1..$9 for std::regex_replace
    static std::string norm_expansion(const std::string& exp) {
        std::string out;
        for (size_t i = 0; i < exp.size(); ++i) {
            if (exp[i] == '\\' && i+1 < exp.size() && exp[i+1] >= '1' && exp[i+1] <= '9') {
                out += '$';
                out += exp[++i];
            } else {
                out += exp[i];
            }
        }
        return out;
    }

    std::string apply_rewrites(const std::string& src) const {
        std::string s = src;
        for (auto& r : rules_) {
            if (r.kind != DynamicRule::Kind::REWRITE) continue;
            if (r.pattern.empty()) continue;
            try {
                std::regex re(r.pattern, std::regex::ECMAScript | std::regex::multiline);
                std::string exp = norm_expansion(r.expansion);
                s = std::regex_replace(s, re, exp);
            } catch (...) {}
        }
        return s;
    }

    // ── greedy match: does src[pos..] start a registered dynop? ──
    // Returns the matching symbol, or "" if none.
    std::string match_dynop_at(const std::string& src, size_t pos) const {
        for (auto& op : ops_) {  // sorted longest-first
            if (pos + op.symbol.size() <= src.size() &&
                src.compare(pos, op.symbol.size(), op.symbol) == 0)
                return op.symbol;
        }
        return "";
    }

    // ── registry JSON dump ────────────────────────────────────────
    std::string dump_json() const {
        auto esc = [](const std::string& s) {
            std::string r; for (char c : s)
                if (c=='"') r+="\\\""; else if(c=='\\') r+="\\\\"; else r+=c;
            return r;
        };
        std::string o = "{\n  \"tokens\":[\n";
        bool first = true;
        for (auto& t : tokens_) {
            if (t.name.empty()) continue;
            if (!first) o+=",\n"; first=false;
            o += "    {\"id\":"+std::to_string(t.token_id)+
                 ",\"name\":\""+esc(t.name)+
                 "\",\"pattern\":\""+esc(t.pattern)+
                 "\",\"category\":\""+esc(t.category)+
                 "\",\"desc\":\""+esc(t.description)+"\"}";
        }
        o += "\n  ],\n  \"rules\":[\n"; first=true;
        for (auto& r : rules_) {
            if (!first) o+=",\n"; first=false;
            std::string ks = (r.kind==DynamicRule::Kind::REWRITE)?"rewrite":
                             (r.kind==DynamicRule::Kind::MACRO)?"macro":
                             (r.kind==DynamicRule::Kind::INFIX_OP)?"infix_op":"prefix_op";
            o += "    {\"name\":\""+esc(r.name)+
                 "\",\"kind\":\""+ks+
                 "\",\"trigger\":\""+esc(r.trigger_token)+
                 "\",\"pattern\":\""+esc(r.pattern)+
                 "\",\"expansion\":\""+esc(r.expansion)+
                 "\",\"prec\":"+std::to_string(r.precedence)+
                 ",\"desc\":\""+esc(r.description)+"\"}";
        }
        o += "\n  ],\n  \"operators\":[\n"; first=true;
        for (auto& op : ops_) {
            if (!first) o+=",\n"; first=false;
            std::string as = (op.arity==DynamicOperator::Arity::PREFIX)?"prefix":
                             (op.arity==DynamicOperator::Arity::INFIX)?"infix":"postfix";
            o += "    {\"symbol\":\""+esc(op.symbol)+
                 "\",\"arity\":\""+as+
                 "\",\"prec\":"+std::to_string(op.precedence)+
                 ",\"desc\":\""+esc(op.description)+"\"}";
        }
        o += "\n  ]\n}";
        return o;
    }

    int  version() const { return ver_; }
    void reset() {
        std::lock_guard<std::mutex> lk(mtx_);
        tokens_.clear(); tmap_.clear();
        rules_.clear(); ops_.clear();
        ver_++;
    }

private:
    DynamicLangRegistry() = default;
    mutable std::mutex mtx_;
    std::vector<DynamicToken>    tokens_;
    std::unordered_map<std::string,int> tmap_;
    std::vector<DynamicRule>     rules_;
    std::vector<DynamicOperator> ops_;
    int ver_ = 0;
};

// ── Helpers used by both Lexer and Parser ──────────────────────────
// Decode a tagged token value back to the original word.
//   "__dyntok:3:emit"  →  "emit"   (dynamic keyword)
//   "__dynop:??"       →  "??"     (dynamic operator)
inline bool is_dyntok_value(const std::string& v) {
    return v.size() > 9 && v.substr(0, 9) == "__dyntok:";
}
inline bool is_dynop_value(const std::string& v) {
    return v.size() > 8 && v.substr(0, 8) == "__dynop:";
}
inline std::string decode_dyntok_name(const std::string& v) {
    // "__dyntok:3:emit" → "emit"
    auto p1 = v.find(':', 9);
    return (p1 != std::string::npos) ? v.substr(p1+1) : v;
}
inline std::string decode_dynop_sym(const std::string& v) {
    // "__dynop:??" → "??"
    return v.substr(8);
}

#pragma GCC diagnostic pop

} // namespace nython
