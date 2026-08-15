# ─── Online-learning coding agent ────────────────────────────────────────────
# An agent that learns while people are coding, in the literal sense: every
# observed piece of source code produces one real gradient-descent update
# (via lib/nytorch/autograd.ny's Variable/AdamVar), not a deferred batch
# retrain. Grounded in the real language, not an invented toy grammar: the
# token categories below come from the same keyword vocabulary the shipped
# syntax highlighter (ide_editor.ny's SyntaxHighlighter) and the real lexer
# (IToken.hpp) use, and tokenize_categories() below follows the same
# char-scan approach that highlighter already uses, kept self-contained here
# rather than imported so nytorch does not gain a GUI dependency.
#
# What it learns: a tiny next-token-CATEGORY language model (keyword /
# identifier / number / string / operator / punct) — small enough to run
# without real ND tensors, but a genuine sequence model, trained online, that
# gets measurably better at predicting Nython's own syntactic structure the
# more real source it observes. See examples/vm_audit40.ny for the evidence:
# perplexity on a held-out file drops as more OTHER files are learned from
# first — the actual signature of learning, not memorising a fixed answer.
#
#   var agent = CodingAgent("demo", "/tmp/ny_agent", 12, 7)
#   agent.observe_file("examples/some_file.ny")
#   agent.suggest_next("keyword")     # -> most likely category after a keyword
#   agent.perplexity_on(some_text)    # lower is better, evaluated without training

# ── real vocabulary, not an invented one ─────────────────────────────────────
# The same keyword list ide_editor.ny's SyntaxHighlighter ships with —
# duplicated rather than imported (nytorch has no business depending on GUI
# code), but sourced from the same real language, not reinvented.
def _ny_keywords():
    return ["def", "class", "if", "elif", "else", "while", "for", "in",
            "return", "import", "var", "const", "let", "not", "and", "or",
            "xor", "true", "false", "none", "print", "self", "do", "end",
            "break", "continue", "try", "except", "catch", "finally",
            "raise", "throw", "with", "as", "pass", "lambda", "yield",
            "from", "global", "del", "assert", "enum", "interface",
            "struct", "namespace", "module", "new", "is", "instanceof",
            "switch", "case", "default", "async", "await", "static",
            "super", "private", "protected", "public", "extends",
            "implements", "inherits", "use", "unless", "repeat", "until",
            "loop", "delete", "sizeof", "typeof", "execute", "block",
            "package", "fn", "fun", "function"]

var KIND_VOCAB = ["keyword", "identifier", "number", "string", "operator", "punct"]
var KIND_INDEX = {"keyword": 0, "identifier": 1, "number": 2, "string": 3, "operator": 4, "punct": 5}
var KIND_COUNT = 6

def _in_keywords(w):
    var kws = _ny_keywords()
    var i = 0
    while i < len(kws):
        if kws[i] == w:
            return true
        i = i + 1
    return false

def _is_id_char(ch):
    if ch >= "a" and ch <= "z":
        return true
    if ch >= "A" and ch <= "Z":
        return true
    if ch >= "0" and ch <= "9":
        return true
    return ch == "_"

def _is_op_char(ch):
    if ch == "+": return true
    if ch == "-": return true
    if ch == "*": return true
    if ch == "/": return true
    if ch == "%": return true
    if ch == "=": return true
    if ch == "<": return true
    if ch == ">": return true
    if ch == "!": return true
    if ch == "&": return true
    if ch == "|": return true
    if ch == "^": return true
    if ch == "~": return true
    return false

# A real (if coarse) tokeniser: comments and whitespace are skipped, string
# literals and numbers are scanned as whole spans, identifiers are checked
# against the real keyword list, everything else falls to operator/punct.
# Returns category strings, not the underlying text — the language model
# below only ever needs the category sequence.
def tokenize_categories(line):
    var cats = []
    var n = len(line)
    var i = 0
    while i < n:
        var ch = line[i:i + 1]
        if ch == " " or ch == "\t":
            i = i + 1
        elif ch == "#":
            i = n
        elif ch == "\"" or ch == "'":
            var quote = ch
            var j = i + 1
            while j < n and line[j:j + 1] != quote:
                j = j + 1
            if j < n:
                j = j + 1
            cats.append("string")
            i = j
        elif ch >= "0" and ch <= "9":
            var j2 = i
            while j2 < n and ((line[j2:j2 + 1] >= "0" and line[j2:j2 + 1] <= "9") or line[j2:j2 + 1] == "."):
                j2 = j2 + 1
            cats.append("number")
            i = j2
        elif _is_id_char(ch) and not (ch >= "0" and ch <= "9"):
            var j3 = i
            while j3 < n and _is_id_char(line[j3:j3 + 1]):
                j3 = j3 + 1
            var word = line[i:j3]
            if _in_keywords(word):
                cats.append("keyword")
            else:
                cats.append("identifier")
            i = j3
        elif _is_op_char(ch):
            cats.append("operator")
            i = i + 1
        else:
            cats.append("punct")
            i = i + 1
    return cats


# ── a tiny online sequence model ─────────────────────────────────────────────
# Predicts the next token CATEGORY from the current one. Not a real language
# model in the LLM sense - a single-hidden-layer MLP over a 6-way categorical
# vocabulary is deliberately small - but it is a genuine, trained,
# gradient-descent-updated model of Nython's own syntactic structure, which
# nothing in nytorch had before.
class TokenLanguageModel:
    def __init__(self, hidden, seed):
        self.n_kinds = KIND_COUNT
        self.model = MLPVar([self.n_kinds, hidden, self.n_kinds], seed)
        self.opt = AdamVar(self.model.parameters(), 0.02, 0.9, 0.999, 0.00000001)
        self.updates = 0

    def _onehot(self, idx):
        var v = zeros(self.n_kinds)
        v[idx] = 1.0
        return Variable(tensor(v), false)

    # One real gradient-descent step given a (previous, next) category pair
    # — "learns on the fly" in the literal sense: every call is a live
    # update, not something queued for a later batch retrain.
    def observe_pair(self, prev_idx, next_idx):
        self.opt.zero_grad()
        var x = self._onehot(prev_idx)
        var logits = self.model.forward(x)
        var loss = softmax_cross_entropy(logits, next_idx)
        loss.backward()
        self.opt.step()
        self.updates = self.updates + 1
        return loss.data

    def observe_sequence(self, indices):
        var total = 0.0
        var i = 0
        while i < len(indices) - 1:
            total = total + self.observe_pair(indices[i], indices[i + 1])
            i = i + 1
        return total

    def predict_next(self, prev_idx):
        var x = self._onehot(prev_idx)
        var logits = self.model.forward(x)
        var best = 0
        var bi = 1
        while bi < self.n_kinds:
            if logits.data[bi] > logits.data[best]:
                best = bi
            bi = bi + 1
        return best

    # Average cross-entropy over a sequence WITHOUT updating any weight —
    # the standard way to check whether the model generalises to text it
    # has not trained on, rather than only memorising what it has already
    # seen.
    def evaluate(self, indices):
        var total = 0.0
        var n = 0
        var i = 0
        while i < len(indices) - 1:
            var x = self._onehot(indices[i])
            var logits = self.model.forward(x)
            var loss = softmax_cross_entropy(logits, indices[i + 1])
            total = total + loss.data
            n = n + 1
            i = i + 1
        if n == 0:
            return 0.0
        return total / n


# ── persistent per-agent memory ──────────────────────────────────────────────
# Deliberately NOT named KnowledgeBase: that name is independently defined
# three different, incompatible ways across nytorch's own submodules
# (compute.ny, memory.ny, storage.ny — a fourth, also incompatible version
# lives in lib/aiagent.ny) — plain-text import order picks whichever was
# imported last, and a caller written against a DIFFERENT one of those four
# silently gets `none` back from every call instead of an error, since a
# missing method resolves that way here rather than raising. Confirmed by
# probe before writing this note. Ten class names collide this way across
# nytorch/ alone; worth its own dedicated rename-and-fix pass (see
# HANDOFF.md), not attempted here — this file just does not add to the
# pile.
class AgentKnowledge:
    def __init__(self, store_path):
        self.store = store_path
        fs_mkdirs(path_dirname(store_path))

    def remember(self, key, value):
        return kv_set(self.store, key, value)

    def recall(self, key):
        return kv_get(self.store, key)

    def has(self, key):
        return kv_get(self.store, key) != none


# ── the agent itself ─────────────────────────────────────────────────────────
class CodingAgent:
    def __init__(self, agent_id, storage_dir, hidden, seed):
        self.agent_id = agent_id
        self.model = TokenLanguageModel(hidden, seed)
        self.kb = AgentKnowledge(storage_dir + "/" + agent_id + "/agent_kb.kv")
        self.files_seen = 0
        self.tokens_seen = 0

    def _categorize(self, text):
        var lines = string_split(text, "\n")
        var cats = []
        var i = 0
        while i < len(lines):
            cats = cats + tokenize_categories(lines[i])
            i = i + 1
        var idxs = []
        var j = 0
        while j < len(cats):
            idxs.append(KIND_INDEX[cats[j]])
            j = j + 1
        return idxs

    # Trains on one piece of real source, one gradient step per adjacent
    # token-category pair — exactly the granularity a user typing would
    # produce it at.
    def observe_source(self, text):
        var idxs = self._categorize(text)
        var loss_sum = self.model.observe_sequence(idxs)
        self.files_seen = self.files_seen + 1
        self.tokens_seen = self.tokens_seen + len(idxs)
        self.kb.remember("files_seen", str(self.files_seen))
        self.kb.remember("tokens_seen", str(self.tokens_seen))
        return loss_sum

    def observe_file(self, path):
        var text = read_file(path)
        if text == none:
            return 0.0
        return self.observe_source(text)

    def suggest_next(self, prev_category):
        if not KIND_INDEX.has_key(prev_category):
            return "identifier"
        var idx = KIND_INDEX[prev_category]
        var best = self.model.predict_next(idx)
        return KIND_VOCAB[best]

    # Perplexity-style score (average cross-entropy, no training) on text
    # the agent has not been trained on — the actual measure of whether it
    # learned something general about Nython's structure.
    def perplexity_on(self, text):
        var idxs = self._categorize(text)
        return self.model.evaluate(idxs)
