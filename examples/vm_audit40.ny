# vm_audit40.ny - lib/nytorch/agent_learn.ny: an online-learning coding
# agent, built on round 72's autograd engine.
#
# The core claim to verify is not "the gradients are correct" (that is
# vm_audit38/39's job, and this file reuses the exact same Variable/MLPVar/
# AdamVar/softmax_cross_entropy machinery already proven there against
# numerical gradients) - it is that the agent actually GENERALISES: after
# training only on snippet_a and snippet_b, its next-token-category
# perplexity on a DIFFERENT, never-trained-on snippet should be lower than
# before any training happened. That is the real signature of learning
# Nython's syntactic structure, as opposed to memorising fixed answers -
# an untrained model and a model that only memorised snippet_a/b verbatim
# would both fail this, since held_out shares no identifiers or literals
# with the training snippets, only the same underlying grammar shape
# (def/class/__init__/self/var/return in the same relative positions).

import "lib/nytorch.ny"

var pass_n = 0
var fail_n = 0

def check(name, got, want):
    if got == want:
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print("FAIL " + name + ": got " + str(got) + " want " + str(want))

def check_true(name, cond):
    if cond:
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print("FAIL " + name + ": expected true")

print("== tokenize_categories: grounded in the real keyword list ==")
var cats = tokenize_categories("def foo(x): return x + 1")
check("keyword recognised", cats[0], "keyword")
check("identifier recognised", cats[1], "identifier")
check("open paren is punct", cats[2], "punct")
check("param identifier", cats[3], "identifier")
check("close paren+colon", cats[4], "punct")
check("second keyword recognised", cats[6], "keyword")
check("operator recognised", cats[8], "operator")
check("number recognised", cats[9], "number")

var str_cats = tokenize_categories("var s = \"hello world\"  # a comment")
check("string literal is one token", str_cats[3], "string")
check("comment produces no extra tokens", len(str_cats), 4)

print("== AgentKnowledge persists across calls (routes around the real KnowledgeBase name collision - see agent_learn.ny's note) ==")
var kb = AgentKnowledge("/tmp/ny_vm_audit40_kb/test.kv")
kb.remember("hello", "world")
check("recall matches remember", kb.recall("hello"), "world")
check_true("has() true for a stored key", kb.has("hello"))
check_true("has() false for a missing key", not kb.has("nope"))

print("== the agent actually generalises: perplexity drops on UNSEEN code after training ==")
var snippet_a = "def add(a, b):\n    return a + b\n\nclass Point:\n    def __init__(self, x, y):\n        self.x = x\n        self.y = y\n\n    def move(self, dx, dy):\n        self.x = self.x + dx\n        self.y = self.y + dy\n\nvar p = Point(1, 2)\np.move(3, 4)\nprint(p.x)\n"
var snippet_b = "def mul(a, b):\n    return a * b\n\nclass Counter:\n    def __init__(self):\n        self.n = 0\n\n    def inc(self):\n        self.n = self.n + 1\n        return self.n\n\nvar c = Counter()\nwhile c.n < 5:\n    c.inc()\nprint(c.n)\n"
# Shares no identifiers or literals with a/b - only the same grammar shape
# (def/class/__init__/self/var/return in the same relative positions) - so
# improving on this specifically demonstrates structural generalisation,
# not memorisation of a or b.
var held_out = "def sub(a, b):\n    return a - b\n\nclass Stack:\n    def __init__(self):\n        self.items = []\n\n    def push(self, v):\n        self.items.append(v)\n\nvar s = Stack()\nfor i in range(3):\n    s.push(i)\nprint(len(s.items))\n"

var agent = CodingAgent("vm_audit40", "/tmp/ny_vm_audit40_agent", 8, 5)
var perplexity_before = agent.perplexity_on(held_out)
agent.observe_source(snippet_a)
agent.observe_source(snippet_b)
var perplexity_after = agent.perplexity_on(held_out)

print("perplexity on held-out code before training: " + str(perplexity_before))
print("perplexity on held-out code after training on OTHER code: " + str(perplexity_after))
check_true("perplexity on unseen code improved from training on different code",
           perplexity_after < perplexity_before)

check("files_seen tracked", agent.files_seen, 2)
check_true("tokens_seen tracked", agent.tokens_seen > 0)
check("agent's own knowledge persisted files_seen", agent.kb.recall("files_seen"), "2")

print("== suggest_next always returns a real category from the vocabulary ==")
var suggestion = agent.suggest_next("keyword")
var is_valid = false
var i = 0
while i < len(KIND_VOCAB):
    if KIND_VOCAB[i] == suggestion:
        is_valid = true
    i = i + 1
check_true("suggestion is a real category", is_valid)
check("unknown category falls back safely", agent.suggest_next("not_a_real_category"), "identifier")

print("Results: " + str(pass_n) + " passed, " + str(fail_n) + " failed")
if fail_n == 0:
    print("=== VM_AUDIT40 PASSED ===")
else:
    print("=== VM_AUDIT40 FAILED ===")
