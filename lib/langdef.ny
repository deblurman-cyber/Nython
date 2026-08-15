# ═══════════════════════════════════════════════════════════════════════════════
# lib/langdef.ny — Nython Runtime Language Extension API
# ═══════════════════════════════════════════════════════════════════════════════
#
# This library exposes a clean, high-level interface for defining new language
# constructs at runtime. Changes take effect for any code subsequently parsed
# by `lang.eval()` or any future `import` inside the same session.
#
# Quick-start:
#
#   import "lib/langdef.ny"
#
#   # 1. Register a new keyword
#   lang.token("emit")
#
#   # 2. Define a REWRITE rule (regex pre-processor, applied before lexing)
#   lang.rewrite("unless_rule",
#       r"unless\s+(.+?)\s*:",
#       r"if not \1:")
#
#   # 3. Define a MACRO (Nython handler called at statement level)
#   lang.macro("log_rule", "log", lambda msg: print("[LOG] " + msg))
#
#   # 4. Define a custom infix operator keyword
#   lang.token("into")
#   lang.infix("into_rule", "into", lambda a, b: b(a))
#
#   # 5. Test immediately with lang.eval
#   lang.eval("log \"hello world\"")
#
# ═══════════════════════════════════════════════════════════════════════════════

class LangDef:
    # ── Token registry ────────────────────────────────────────────────────
    def token(self, name, pattern="", category="keyword", description=""):
        """Register a new keyword token. After this, the lexer recognises
        `name` (or anything matching `pattern`) as a dynamic keyword and
        the parser can route it to a macro or infix rule."""
        return lang_define_token(name, pattern, category, description)

    def remove_token(self, name):
        """Unregister a previously defined keyword token."""
        return lang_remove_token(name)

    # ── Rule definitions ──────────────────────────────────────────────────
    def rewrite(self, name, pattern, expansion, description=""):
        """Define a source-level REWRITE rule.
        `pattern` is an ECMAScript regex applied to the whole source string
        before lexing; `expansion` is the substitution template.

        Example — add 'unless' as syntactic sugar for 'if not':
            lang.rewrite("unless_rule",
                r"unless\\s+(.+?)\\s*:",
                r"if not \\1:")
        """
        lang_define_token(name + "_tok", "", "keyword", description)
        return lang_define_rule(name, "rewrite", "", pattern, expansion)

    def macro(self, name, trigger_token, handler_fn, description=""):
        """Define a MACRO rule: when `trigger_token` is seen at statement
        level, call handler_fn(*token_args) where token_args are the
        remaining tokens on the line as strings.

        Example:
            lang.token("log")
            lang.macro("log_rule", "log", lambda msg: print("[LOG] " + msg))
            # Now: log \"hello\"  calls the lambda with "hello"
        """
        return lang_define_macro(name, trigger_token, handler_fn)

    def infix(self, name, trigger_token, handler_fn, precedence=50, description=""):
        """Define an INFIX operator rule: when `trigger_token` appears
        between two expressions, call handler_fn(lhs, rhs).

        Example:
            lang.token("has")
            lang.infix("has_rule", "has", lambda a, b: b in a)
            # Now: [1,2,3] has 2  evaluates to true
        """
        return lang_define_infix(name, trigger_token, handler_fn, precedence)

    def prefix(self, name, trigger_token, handler_fn, description=""):
        """Define a PREFIX operator rule: when `trigger_token` appears
        before an expression, call handler_fn(operand).

        Example:
            lang.token("double")
            lang.prefix("double_rule", "double", lambda x: x * 2)
        """
        return lang_define_prefix(name, trigger_token, handler_fn)

    def operator(self, symbol, handler_fn, arity="infix", precedence=50, description=""):
        """Register a symbolic operator (non-identifier chars like ??, <~>, >>>).
        The lexer will recognise the symbol and the executor will call
        handler_fn with the appropriate operands.

        Example:
            lang.operator("??", lambda a, b: a if a != none else b,
                          arity="infix", precedence=30)
        """
        return lang_define_operator(symbol, arity, precedence, handler_fn, description)

    def remove_rule(self, name):
        """Remove a REWRITE, MACRO or operator rule by name."""
        return lang_remove_rule(name)

    def remove_operator(self, symbol):
        """Remove a symbolic operator registration."""
        return lang_remove_operator(symbol)

    # ── Evaluation ────────────────────────────────────────────────────────
    def eval(self, code):
        """Re-lex and execute `code` with all registered REWRITE rules
        applied as a pre-processing step. Use this to test your extensions
        interactively or to run generated code."""
        return lang_eval(code)

    # ── Inspection ────────────────────────────────────────────────────────
    def tokens(self):
        """Return a list of dicts describing all registered dynamic tokens."""
        return lang_list_tokens()

    def rules(self):
        """Return a list of dicts describing all registered rules."""
        return lang_list_rules()

    def operators(self):
        """Return a list of dicts describing all registered operators."""
        return lang_list_operators()

    def registry_json(self):
        """Return the entire registry as a JSON string (for serialisation
        or display in the Language Workshop IDE panel)."""
        return lang_registry_json()

    def version(self):
        """Return the registry version counter (increments on every change)."""
        return lang_version()

    def reset(self):
        """Remove ALL registered tokens, rules and operators."""
        return lang_reset()

    def summary(self):
        """Print a human-readable summary of the current language extensions."""
        var toks = self.tokens()
        var rul  = self.rules()
        var ops  = self.operators()
        print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print "  Nython Language Extensions  (v" + str(self.version()) + ")"
        print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print "  Tokens:    " + str(len(toks))
        var i = 0
        while i < len(toks):
            var t = toks[i]
            var pat = ""
            if len(t["pattern"]) > 0:
                pat = "  [regex: " + t["pattern"] + "]"
            print "    • " + t["name"] + "  (" + t["category"] + ")" + pat
            i = i + 1
        print "  Rules:     " + str(len(rul))
        i = 0
        while i < len(rul):
            var r = rul[i]
            var detail = ""
            if r["kind"] == "rewrite":
                detail = "  → " + r["expansion"]
            elif r["kind"] == "macro" or r["kind"] == "infix_op" or r["kind"] == "prefix_op":
                detail = "  (handler fn)"
            print "    • [" + r["kind"] + "] " + r["name"] + "  trigger='" + r["trigger"] + "'" + detail
            i = i + 1
        print "  Operators: " + str(len(ops))
        i = 0
        while i < len(ops):
            var o = ops[i]
            print "    • '" + o["symbol"] + "'  " + o["arity"] + "  prec=" + str(o["prec"])
            i = i + 1
        print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


# ── Singleton instance ────────────────────────────────────────────────────────
var lang = LangDef()


# ═══════════════════════════════════════════════════════════════════════════════
# Built-in extension packs — optional, import what you need
# ═══════════════════════════════════════════════════════════════════════════════

class LangPack_Control:
    """Adds Python-style control flow sugar: unless, until, repeat_n."""
    def install(self):
        # unless <cond>: → if not <cond>:
        lang.rewrite("unless_kw",
            "unless\\s+(.+?)\\s*:",
            "if not \\1:")

        # until <cond>: → while not <cond>:
        lang.rewrite("until_kw",
            "until\\s+(.+?)\\s*:",
            "while not \\1:")

        print "[LangPack_Control] installed: unless, until"
        return self

    def uninstall(self):
        lang.remove_rule("unless_kw")
        lang.remove_rule("until_kw")
        return self


class LangPack_Pipe:
    """Adds a pipe operator: a |> f  means f(a)."""
    def install(self):
        lang.token("pipe_op", "", "operator", "Pipe operator token")
        # Rewrite:  a |> f   →  f(a)
        # We use a rewrite because |> is a two-char token the lexer splits
        lang.rewrite("pipe_rewrite",
            "\\|>",
            " __pipe__ ")
        lang.token("__pipe__", "", "operator", "internal pipe marker")
        lang.infix("pipe_rule", "__pipe__",
            lambda a, b: b(a), 20)
        print "[LangPack_Pipe] installed: |> pipe operator"
        return self

    def uninstall(self):
        lang.remove_rule("pipe_rewrite")
        lang.remove_rule("pipe_rule")
        lang.remove_token("__pipe__")
        return self


class LangPack_Null:
    """Adds null-coalescing operator via a 'or_else' keyword:
       a or_else b  →  a if a != none else b
    """
    def install(self):
        lang.token("or_else", "", "operator", "null-coalescing operator")
        lang.infix("or_else_rule", "or_else",
            lambda a, b: a if a != none else b, 15)
        print "[LangPack_Null] installed: or_else null-coalescing"
        return self

    def uninstall(self):
        lang.remove_rule("or_else_rule")
        lang.remove_token("or_else")
        return self


class LangPack_Debug:
    """Adds a 'dbg' macro that prints expression + value."""
    def install(self):
        lang.token("dbg", "", "keyword", "debug print macro")
        lang.macro("dbg_rule", "dbg",
            lambda expr_str: print("[DBG] " + expr_str + " = " + str(lang.eval(expr_str))))
        print "[LangPack_Debug] installed: dbg macro"
        return self

    def uninstall(self):
        lang.remove_rule("dbg_rule")
        lang.remove_token("dbg")
        return self
