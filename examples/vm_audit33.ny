# vm_audit33.ny - regressions for round 41.
# Found while writing a theme test that reported "0 failed" on both engines
# while silently running 19 fewer assertions on one of them.

print("== loop body runs every iteration ==")
# The parser yields a BARE expression node as a loop body when the body is a
# single expression - which is what happens after a multi-line list literal in
# the loop header. Only BLOCK bodies reached visit_stmt's POP_TOP, so a
# call-as-body left its return value on the stack each iteration. FOR_ITER
# reads stack_.back(), so it then read that leftover instead of the iterator
# and the loop ran exactly ONCE, with no error reported.
var hits = 0
def tick(x):
    hits = hits + 1

hits = 0
for n in ["a","b",
          "c","d"]:
    tick(n)
print("multi-line list + call: " + str(hits))

hits = 0
for n in ["a","b","c","d"]:
    tick(n)
print("single-line list + call: " + str(hits))

hits = 0
for n in ["a","b",
          "c","d"]:
    hits = hits + 1
print("multi-line list, no call: " + str(hits))

hits = 0
var i = 0
while i < 4:
    tick(i)
    i = i + 1
print("while + call: " + str(hits))

# nested, both headers multi-line
hits = 0
for a in ["p",
          "q"]:
    for b in ["r",
              "s"]:
        tick(b)
print("nested multi-line: " + str(hits))

print("== ternaries keep their value ==")
# Nython has no separate ternary node - `a if c else b` is an IfNode - so the
# fix above must NOT be applied to if-branches. When it briefly was, a dict
# literal holding a ternary whose branch was a call came out with its keys and
# values swapped: {5: 'avg_confidence', none: 'n_steps'}.
class S:
    def __init__(self):
        self.n = 5
        self.xs = [1, 2, 3]
    def summary(self):
        return {
            "n": self.n,
            "count": len(self.xs),
            "avg": float(sum(self.xs)) if len(self.xs) > 0 else 0.0
        }
var s = S()
var d = s.summary()
print(str(d["n"]) + " " + str(d["count"]) + " " + str(d["avg"]))
print(5 if true else 6)
print(5 if false else 6)
var t = [1 if true else 2, 3 if false else 4]
print(str(t))

print("vm_audit33 ok")
