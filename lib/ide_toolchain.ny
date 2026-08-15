# ─── IDE Toolchain Bridge ────────────────────────────────────────────────────
# Runs the REAL nython binary and returns its REAL output.
#
# Before this existed, the IDE's Run / Debug / Tokenize / AST / Disassemble
# buttons were mockups: `_run_file` scanned the buffer for lines starting with
# "print " and echoed the text after them, then reported "0 errors" and a
# hardcoded 42 ms every single time. It could not fail, could not print anything
# a real run would print, and would happily report success for a file with a
# syntax error in it. `_ast_file` pattern-matched lines into invented XML;
# `_disasm_file` emitted one "EXEC" per non-blank line; `_profile_file` made up
# timings. None of them ever touched the compiler.
#
# Everything here shells out to the actual toolchain via os_exec and parses what
# comes back, so what the IDE shows is what the language actually does.
#
#   var tc = Toolchain()
#   var r = tc.run(source, false)     # r.ok, r.lines, r.exit_code, r.ms
#   var d = tc.diagnose(source)       # list of {line, severity, message}

class Diagnostic:
    def __init__(self, line, severity, message):
        self.line = line
        self.severity = severity      # "error" | "warning" | "info"
        self.message = message


class ToolResult:
    def __init__(self):
        self.ok = true
        self.lines = []
        self.line_count = 0
        self.exit_code = 0
        self.ms = 0
        self.raw = ""
        self.profile_rows = []
        self.profile_count = 0

    def add(self, text):
        self.lines.append(text)
        self.line_count = self.line_count + 1


class Toolchain:
    def __init__(self):
        self.exe = self._find_exe()
        self.tmp_dir = "/tmp"
        self.seq = 0
        self.last_command = ""

    # The IDE may be launched from anywhere; prefer a binary sitting next to the
    # workspace, then fall back to PATH.
    def _find_exe(self):
        for cand in ["./nython", "./ny_test", "./build/nython"]:
            if path_exists(cand):
                return cand
        return "nython"

    def available(self):
        var probe = os_exec(self.exe + " --version 2>&1")
        return string_find(probe, "Nython") >= 0

    def version(self):
        return os_exec(self.exe + " --version 2>&1")

    # ── temp file plumbing ───────────────────────────────────────────────────
    def _temp_path(self, name):
        self.seq = self.seq + 1
        var safe = name
        if len(safe) == 0:
            safe = "buffer"
        return self.tmp_dir + "/nyide_" + str(self.seq) + "_" + safe

    def _stage(self, source, name):
        var p = self._temp_path(name)
        write_file(p, source)
        return p

    # Runs a command, capturing stdout+stderr together and the exit status.
    # os_exec only returns output, so the status is smuggled out on a final line.
    def _exec(self, cmd):
        self.last_command = cmd
        var full = "{ " + cmd + " ; } 2>&1 ; echo __NY_EXIT__$?"
        var raw = os_exec(full)
        var res = ToolResult()
        res.raw = raw
        var parts = string_split(raw, "\n")
        var i = 0
        while i < len(parts):
            var ln = parts[i]
            if string_startswith(ln, "__NY_EXIT__"):
                res.exit_code = int(ln[11:])
            else:
                res.add(ln)
            i = i + 1
        res.ok = res.exit_code == 0
        return res

    def _timed(self, cmd):
        var t0 = time_now()
        var res = self._exec(cmd)
        res.ms = int((time_now() - t0) * 1000.0)
        return res

    # ── pipeline modes ───────────────────────────────────────────────────────
    def run(self, source, name, use_vm):
        var p = self._stage(source, name)
        var flag = ""
        if use_vm:
            flag = "--vm "
        return self._timed(self.exe + " " + flag + p)

    def tokenize(self, source, name):
        var p = self._stage(source, name)
        return self._timed(self.exe + " -t " + p)

    def ast(self, source, name):
        var p = self._stage(source, name)
        return self._timed(self.exe + " -a " + p)

    def disasm(self, source, name):
        var p = self._stage(source, name)
        return self._timed(self.exe + " -d " + p)

    # ── profiling ────────────────────────────────────────────────────────────
    # Runs under `--profile` and splits the measured report off the program's
    # own stdout. Rows are [name, calls, total_ms, self_ms], hottest first.
    def profile(self, source, name):
        var p = self._stage(source, name)
        var res = self._timed(self.exe + " --profile " + p)
        var rows = []
        var in_report = false
        var i = 0
        while i < res.line_count:
            var ln = res.lines[i]
            if ln == "__NY_PROFILE__":
                in_report = true
            elif in_report:
                if string_find(ln, ",") >= 0 and not string_startswith(ln, "name,"):
                    var parts = string_split(ln, ",")
                    if len(parts) >= 4:
                        rows.append([parts[0], int(parts[1]),
                                     float(parts[2]), float(parts[3])])
            i = i + 1
        res.profile_rows = rows
        res.profile_count = len(rows)
        return res

    # Program output only, with the profile report stripped off.
    def split_program_output(self, res):
        var out = []
        var i = 0
        while i < res.line_count:
            if res.lines[i] == "__NY_PROFILE__":
                i = res.line_count
            else:
                out.append(res.lines[i])
            i = i + 1
        return out

    # ── diagnostics ──────────────────────────────────────────────────────────
    # Compile without running, and turn whatever the toolchain complains about
    # into structured diagnostics the PROBLEMS panel can render.
    def diagnose(self, source, name):
        var out = []
        var p = self._stage(source, name)
        var res = self._exec(self.exe + " -a " + p)
        var i = 0
        while i < res.line_count:
            var ln = res.lines[i]
            var d = self._parse_diagnostic(ln)
            if d != none:
                out.append(d)
            i = i + 1
        return out

    def _parse_diagnostic(self, ln):
        if len(ln) == 0:
            return none
        var lower = string_lower(ln)
        var sev = ""
        if string_find(lower, "error") >= 0:
            sev = "error"
        elif string_find(lower, "warning") >= 0:
            sev = "warning"
        if len(sev) == 0:
            return none
        # "[DBG SyntaxError] Expected ParenClose, but found Var"
        var msg = ln
        var rb = string_find(ln, "] ")
        if rb >= 0:
            msg = ln[rb + 2:]
        return Diagnostic(self._line_from(ln), sev, msg)

    # Pull a line number out of the message when the toolchain supplies one.
    def _line_from(self, ln):
        var key = "line "
        var at = string_find(ln, key)
        if at < 0:
            return 0
        var rest = ln[at + 5:]
        var digits = ""
        var i = 0
        while i < len(rest):
            var c = rest[i]
            if c >= "0" and c <= "9":
                digits = digits + c
            else:
                i = len(rest)
            i = i + 1
        if len(digits) == 0:
            return 0
        return int(digits)

    # ── token extraction for the TOKENS panel ────────────────────────────────
    # `-t` emits XML; pull out the fields the viewer actually displays.
    def tokens(self, source, name):
        var res = self.tokenize(source, name)
        var out = []
        var i = 0
        while i < res.line_count:
            var ln = string_strip(res.lines[i])
            if string_startswith(ln, "<Token "):
                var val = self._attr(ln, "value")
                var lno = self._attr(ln, "line")
                var col = self._attr(ln, "column")
                var kind = ""
                if i + 2 < res.line_count:
                    kind = self._attr(string_strip(res.lines[i + 1]), "value")
                out.append([val, kind, lno, col])
            i = i + 1
        return out

    def _attr(self, ln, key):
        var pat = key + "=\""
        var at = string_find(ln, pat)
        if at < 0:
            return ""
        var rest = ln[at + len(pat):]
        var close = string_find(rest, "\"")
        if close < 0:
            return rest
        return rest[0:close]
