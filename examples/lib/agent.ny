# ─── examples/lib/agent.ny ───────────────────────────────────────────────────
# A minimal key/value agent for the v14/v15 examples: learn a fact, recall it,
# report how many are held.

class Agent:
    def __init__(self, name):
        self.name = name
        self.facts = {}
        self.fact_count = 0

    def learn(self, key, value):
        # Re-learning a key overwrites rather than double-counting, so memory()
        # reports distinct facts and not the number of learn() calls.
        if self.facts[key] == none:
            self.fact_count = self.fact_count + 1
        self.facts[key] = value
        return true

    # An unknown key returns none, not "": the examples assert on none, and an
    # empty string would be indistinguishable from a fact whose value is empty.
    def ask(self, key):
        return self.facts[key]

    def knows(self, key):
        return self.facts[key] != none

    def memory(self):
        return self.fact_count

    def forget(self, key):
        if self.facts[key] != none:
            self.facts[key] = none
            self.fact_count = self.fact_count - 1
            return true
        return false

    def __str__(self):
        return "Agent(" + self.name + "," + str(self.fact_count) + " facts)"
