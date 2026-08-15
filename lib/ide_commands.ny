# ─── IDE command line ────────────────────────────────────────────────────────
# A command interpreter for the IDE's terminal panel.
#
# The terminal could run shell commands and the REPL could evaluate expressions,
# but there was no way to *drive the IDE itself* — or to talk to an agent — from
# the keyboard. Everything went through menus, which means anything not on a
# menu was unreachable.
#
# Three namespaces, one prompt:
#
#   :cmd     IDE actions      :run, :build, :open, :find, :goto, :panel
#   >expr    language         evaluated by the real interpreter
#   @agent   AI agents        @ask, @explain, @fix, @test, @doc, @agents
#
# The sigil decides the namespace, so nothing is ambiguous: `:run` is always the
# IDE, `print(1)` is always the language, `@ask why` is always an agent. A bare
# line with no sigil is treated as language input, because that is what a user
# types most often.

class CommandResult:
    def __init__(self, ok, text):
        self.ok = ok
        self.text = text
        self.lines = []
        self.action = ""        # an IDE action for the caller to perform
        self.arg = ""

    def add(self, s):
        self.lines.append(s)
        return self


class CommandLine:
    def __init__(self, toolchain, agent):
        self.tc = toolchain
        self.agent = agent
        self.history = []
        self.hist_pos = 0
        self.session = []          # accepted declarations, for the language REPL
        self.aliases = {}
        self._register_aliases()

    def _register_aliases(self):
        # Short forms people actually type. Kept as data so `:help` can list
        # them rather than the list drifting out of date in a doc comment.
        self.aliases["r"] = "run"
        self.aliases["b"] = "build"
        self.aliases["o"] = "open"
        self.aliases["f"] = "find"
        self.aliases["g"] = "goto"
        self.aliases["q"] = "quit"
        self.aliases["?"] = "help"

    # ── history ──────────────────────────────────────────────────────────────
    def push_history(self, line):
        if len(line) == 0:
            return false
        # Consecutive duplicates are noise when arrowing back through history.
        if len(self.history) > 0 and self.history[len(self.history) - 1] == line:
            self.hist_pos = len(self.history)
            return false
        self.history.append(line)
        self.hist_pos = len(self.history)
        return true

    def history_prev(self):
        if len(self.history) == 0:
            return ""
        self.hist_pos = self.hist_pos - 1
        if self.hist_pos < 0:
            self.hist_pos = 0
        return self.history[self.hist_pos]

    def history_next(self):
        if len(self.history) == 0:
            return ""
        self.hist_pos = self.hist_pos + 1
        if self.hist_pos >= len(self.history):
            self.hist_pos = len(self.history)
            return ""
        return self.history[self.hist_pos]

    # ── dispatch ─────────────────────────────────────────────────────────────
    def execute(self, raw, ctx):
        var line = string_strip(raw)
        if len(line) == 0:
            return CommandResult(true, "")
        self.push_history(line)

        if string_startswith(line, ":"):
            return self._ide_command(line[1:], ctx)
        if string_startswith(line, "@"):
            return self._agent_command(line[1:], ctx)
        if string_startswith(line, ">"):
            return self._eval(string_strip(line[1:]))
        # No sigil: language input, which is what gets typed most.
        return self._eval(line)

    def _split(self, s):
        var parts = string_split(s, " ")
        var out = []
        var i = 0
        while i < len(parts):
            if len(parts[i]) > 0:
                out.append(parts[i])
            i = i + 1
        return out

    # ── IDE namespace ────────────────────────────────────────────────────────
    def _ide_command(self, body, ctx):
        var parts = self._split(body)
        if len(parts) == 0:
            return CommandResult(false, "empty command")
        var verb = string_lower(parts[0])
        var alias = self.aliases[verb]
        if alias != none:
            verb = alias
        var arg = ""
        if len(parts) > 1:
            arg = string_join(parts[1:len(parts)], " ")

        var res = CommandResult(true, "")
        if verb == "help":
            res.add("IDE      :run :build :vm :tokens :ast :disasm :profile")
            res.add("         :open <f> :save :goto <n> :find <t> :panel <name>")
            res.add("         :theme :clear :history :quit")
            res.add("agents   @agents @ask <q> @explain @fix @test @doc")
            res.add("language type an expression, or > expr")
            return res
        if verb == "history":
            var i = 0
            while i < len(self.history):
                res.add(str(i + 1) + "  " + self.history[i])
                i = i + 1
            return res
        if verb == "clear":
            res.action = "clear"
            return res

        # Actions the caller performs, named rather than executed here so the
        # command line stays testable without a window.
        for known in ["run","build","vm","tokens","ast","disasm","profile",
                      "save","theme","quit","open","goto","find","panel"]:
            if verb == known:
                res.action = verb
                res.arg = arg
                res.add(":" + verb + " " + arg)
                return res

        var r = CommandResult(false, "unknown command: " + verb)
        r.add("unknown command '" + verb + "' — try :help")
        return r

    # ── language namespace ───────────────────────────────────────────────────
    # Replays accepted declarations so the session accumulates, exactly as the
    # REPL panel does.
    def _eval(self, expr):
        if self.tc == none:
            return CommandResult(false, "no toolchain")
        var is_decl = false
        for kw in ["var ", "def ", "class ", "import ", "func "]:
            if string_startswith(expr, kw):
                is_decl = true

        var prelude = ""
        var i = 0
        while i < len(self.session):
            prelude = prelude + self.session[i] + "\n"
            i = i + 1

        var program = prelude
        if is_decl:
            program = program + expr + "\n"
        else:
            program = program + "print(" + expr + ")\n"

        var out = self.tc.run(program, "cmdline.ny", false)
        var res = CommandResult(out.ok, "")
        var k = 0
        while k < out.line_count:
            res.add(out.lines[k])
            k = k + 1
        # A declaration joins the session only once it compiles, so one bad line
        # cannot poison every later command.
        if out.ok and is_decl:
            self.session.append(expr)
            res.lines = ["defined"]
        return res

    # ── agent namespace ──────────────────────────────────────────────────────
    def _agent_command(self, body, ctx):
        var parts = self._split(body)
        if len(parts) == 0:
            return CommandResult(false, "empty agent command")
        var verb = string_lower(parts[0])
        var arg = ""
        if len(parts) > 1:
            arg = string_join(parts[1:len(parts)], " ")

        var res = CommandResult(true, "")
        if verb == "agents":
            res.add("available agents:")
            res.add("  explain   describe what the current file does")
            res.add("  fix       propose a fix for the first diagnostic")
            res.add("  test      draft a test for the current file")
            res.add("  doc       draft documentation for the current file")
            res.add("  ask       free-form question about the workspace")
            return res

        # Every agent action names itself and carries its argument; the IDE
        # supplies the file context, because the command line deliberately does
        # not reach into the editor.
        for known in ["ask", "explain", "fix", "test", "doc", "review"]:
            if verb == known:
                res.action = "agent:" + verb
                res.arg = arg
                res.add("[" + verb + "] " + arg)
                return res

        var r = CommandResult(false, "unknown agent: " + verb)
        r.add("unknown agent '" + verb + "' — try @agents")
        return r

    # ── completion ───────────────────────────────────────────────────────────
    # Prefix completion over whichever namespace the sigil selects, so Tab does
    # something useful in all three rather than only for shell paths.
    def complete(self, prefix):
        var out = []
        if string_startswith(prefix, ":"):
            var stem = prefix[1:]
            for c in ["run","build","vm","tokens","ast","disasm","profile","open",
                      "save","goto","find","panel","theme","clear","history",
                      "help","quit"]:
                if string_startswith(c, stem):
                    out.append(":" + c)
            return out
        if string_startswith(prefix, "@"):
            var stem2 = prefix[1:]
            for a in ["agents","ask","explain","fix","test","doc","review"]:
                if string_startswith(a, stem2):
                    out.append("@" + a)
            return out
        return out
