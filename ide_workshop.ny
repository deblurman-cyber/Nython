# ide_workshop.ny — LangWorkshopPanel
# Imported by nython_ide.ny

class LangWorkshopPanel:
    def __init__(self, x, y, w, h):
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.visible = false

        # ── Colours ────────────────────────────────────────────────────────
        self.BG       = Color(14, 16, 28, 255)
        self.PANEL_BG = Color(18, 20, 36, 255)
        self.BORDER   = Color(255, 255, 255, 10)
        self.ACCENT   = Color(99, 102, 241, 255)
        self.DIM      = Color(100, 102, 140, 160)
        self.TEXT     = Color(200, 202, 230, 220)
        self.TEXT_BR  = Color(220, 222, 255, 240)
        self.OK       = Color(74, 222, 128, 200)
        self.WARN     = Color(251, 191, 36, 200)
        self.ERR      = Color(248, 113, 113, 200)
        self.TOK_CLR  = Color(196, 148, 198, 220)
        self.RULE_CLR = Color(86, 196, 186, 220)
        self.OP_CLR   = Color(252, 176, 90, 220)

        # ── Fonts ─────────────────────────────────────────────────────────
        self.F_BODY  = Font("monospace", 11, false, false)
        self.F_BOLD  = Font("monospace", 11, true, false)
        self.F_SMALL = Font("sans-serif", 10, false, false)
        self.F_HEAD  = Font("sans-serif", 12, true, false)

        # ── Layout constants ───────────────────────────────────────────────
        self.FORM_W   = int(w * 0.35)
        self.REG_W    = int(w * 0.35)
        self.TEST_W   = w - self.FORM_W - self.REG_W
        self.PAD      = 12

        # ── Form state ─────────────────────────────────────────────────────
        self.kind_options = ["token", "rewrite", "macro", "infix", "prefix", "operator"]
        self.kind_idx     = 0
        self.f_name       = TextInput(x + self.PAD, y + 60, self.FORM_W - self.PAD * 2, 26)
        self.f_name.placeholder = "name"
        self.f_trigger    = TextInput(x + self.PAD, y + 106, self.FORM_W - self.PAD * 2, 26)
        self.f_trigger.placeholder = "trigger / pattern"
        self.f_expansion  = TextInput(x + self.PAD, y + 152, self.FORM_W - self.PAD * 2, 26)
        self.f_expansion.placeholder = "expansion / description"
        self.f_prec       = TextInput(x + self.PAD, y + 198, 80, 26)
        self.f_prec.value  = "50"
        self.status_msg   = ""
        self.status_kind  = "ok"    # "ok" | "warn" | "err"

        # ── Registry mirror (for display) ─────────────────────────────────
        self.reg_tokens    = []
        self.reg_rules     = []
        self.reg_ops       = []
        self.reg_version   = -1
        self.reg_scroll    = 0
        self.reg_max_rows  = int((h - 30) / 18)

        # ── Live test ─────────────────────────────────────────────────────
        self.test_input  = TextInput(x + self.FORM_W + self.REG_W + self.PAD,
                                     y + 60, self.TEST_W - self.PAD * 2, 26)
        self.test_input.placeholder = "enter code to test, e.g: unless x > 5:"
        self.test_output = []
        self.test_scroll = 0

        # ── Quick-examples dropdown ────────────────────────────────────────
        self.examples = [
            ["unless keyword (rewrite)", "rewrite", "unless_kw", "unless\\s+(.+?)\\s*:", "if not \\1:", "0"],
            ["until keyword (rewrite)",  "rewrite", "until_kw",  "until\\s+(.+?)\\s*:",  "while not \\1:", "0"],
            ["log macro (macro)",        "token+macro", "log", "log", "", "0"],
            ["has operator (infix)",     "token+infix", "has", "has", "", "60"],
            ["pipe |> (rewrite+infix)",  "rewrite", "pipe_rw", "\\|>", " __pipe__ ", "0"],
            ["?? null-coal (token+infix)","token+infix", "or_else", "or_else", "", "15"],
        ]
        self.ex_scroll = 0

        # Selected item for deletion
        self.selected_tok = -1
        self.selected_rule = -1
        self.selected_op = -1

    def show(self):
        self.visible = true
        self._refresh_registry()

    def hide(self):
        self.visible = false

    def _refresh_registry(self):
        self.reg_tokens = lang_list_tokens()
        self.reg_rules  = lang_list_rules()
        self.reg_ops    = lang_list_operators()
        self.reg_version = lang_version()

    def _do_register(self):
        var kind = self.kind_options[self.kind_idx]
        var name = string_strip(self.f_name.text)
        var trig = string_strip(self.f_trigger.text)
        var exp  = string_strip(self.f_expansion.text)
        var prec = 50
        var prec_s = string_strip(self.f_prec.text)
        if len(prec_s) > 0:
            prec = int(prec_s)

        if len(name) == 0:
            self.status_msg  = "? Name is required"
            self.status_kind = "err"
            return

        if kind == "token":
            lang_define_token(name, trig, "keyword", exp)
            self.status_msg  = "[OK] Token '" + name + "' registered"
            self.status_kind = "ok"

        elif kind == "rewrite":
            if len(trig) == 0:
                self.status_msg = "? Pattern required for rewrite"
                self.status_kind = "err"
                return
            lang_define_rule(name, "rewrite", "", trig, exp, prec)
            self.status_msg  = "[OK] Rewrite rule '" + name + "' registered"
            self.status_kind = "ok"

        elif kind == "macro":
            if len(trig) == 0:
                self.status_msg = "? Trigger token required for macro"
                self.status_kind = "err"
                return
            # Auto-register the trigger token if not already present
            lang_define_token(trig, "", "keyword", "auto-registered by macro " + name)
            # Macro with identity handler (prints args)
            lang_define_macro(name, trig, lambda a: print("[macro:" + name + "] " + str(a)))
            self.status_msg  = "[OK] Macro '" + name + "' registered (trigger: '" + trig + "')"
            self.status_kind = "ok"

        elif kind == "infix":
            if len(trig) == 0:
                self.status_msg = "? Trigger token required for infix"
                self.status_kind = "err"
                return
            lang_define_token(trig, "", "operator", "auto-registered by infix rule " + name)
            # Placeholder infix: returns [lhs, rhs] tuple representation
            lang_define_infix(name, trig,
                lambda a, b: str(a) + " " + trig + " " + str(b), prec)
            self.status_msg  = "[OK] Infix op '" + trig + "' registered (rule: " + name + ")"
            self.status_kind = "ok"

        elif kind == "prefix":
            if len(trig) == 0:
                self.status_msg = "? Trigger token required for prefix"
                self.status_kind = "err"
                return
            lang_define_token(trig, "", "operator", "auto-registered by prefix rule " + name)
            lang_define_prefix(name, trig, lambda a: a)
            self.status_msg  = "[OK] Prefix op '" + trig + "' registered (rule: " + name + ")"
            self.status_kind = "ok"

        elif kind == "operator":
            if len(trig) == 0:
                self.status_msg = "? Symbol required for operator"
                self.status_kind = "err"
                return
            lang_define_operator(trig, "infix", prec,
                lambda a, b: str(a) + trig + str(b), exp)
            self.status_msg  = "[OK] Symbol operator '" + trig + "' registered"
            self.status_kind = "ok"

        self._refresh_registry()

    def _do_test(self):
        var code = string_strip(self.test_input.text)
        if len(code) == 0:
            return
        var result = lang_eval(code)
        var line = "> " + code + " -> " + str(result)
        self.test_output.append(line)
        if len(self.test_output) > 50:
            self.test_output = self.test_output[1:]

    def _do_clear_form(self):
        self.f_name.value      = ""
        self.f_trigger.value   = ""
        self.f_expansion.value = ""
        self.f_prec.value      = "50"
        self.status_msg       = ""

    def handle_event(self, event):
        if not self.visible: return

        # Kind selector click (top of form)
        if event.type == "mousedown":
            var kind_y = self.y + 26
            var kind_x = self.x + self.PAD
            var kw     = 72
            var i = 0
            while i < len(self.kind_options):
                var bx = kind_x + i * (kw + 4)
                if event.x >= bx and event.x < bx + kw and event.y >= kind_y and event.y < kind_y + 22:
                    self.kind_idx = i
                    event.consume()
                    return
                i = i + 1

            # Register button
            var btn_x  = self.x + self.PAD
            var btn_y  = self.y + 228
            var btn_w  = 90
            var btn_h  = 26
            if event.x >= btn_x and event.x < btn_x + btn_w and event.y >= btn_y and event.y < btn_y + btn_h:
                self._do_register()
                event.consume()
                return

            # Clear button
            var clr_x = btn_x + btn_w + 10
            if event.x >= clr_x and event.x < clr_x + 70 and event.y >= btn_y and event.y < btn_y + btn_h:
                self._do_clear_form()
                event.consume()
                return

            # Reset all button
            var rst_x = clr_x + 80
            if event.x >= rst_x and event.x < rst_x + 90 and event.y >= btn_y and event.y < btn_y + btn_h:
                lang_reset()
                self._refresh_registry()
                self.test_output = []
                self.status_msg  = "[OK] Registry cleared"
                self.status_kind = "warn"
                event.consume()
                return

            # Test button
            var test_btn_x = self.x + self.FORM_W + self.REG_W + self.PAD
            var test_btn_y = self.y + 96
            if event.x >= test_btn_x and event.x < test_btn_x + 80 and event.y >= test_btn_y and event.y < test_btn_y + 24:
                self._do_test()
                event.consume()
                return

            # Example buttons (right of registry)
            var ex_x = self.x + self.FORM_W + self.PAD
            var ex_y = self.y + 30
            var ex_row_h = 17
            var i2 = 0
            while i2 < len(self.examples):
                var ey = ex_y + i2 * ex_row_h
                if event.x >= ex_x and event.x < ex_x + self.REG_W - self.PAD and event.y >= ey and event.y < ey + ex_row_h - 1:
                    var ex = self.examples[i2]
                    self.kind_idx = 0
                    var k = 0
                    while k < len(self.kind_options):
                        if self.kind_options[k] == ex[0][0:len(self.kind_options[k])]:
                            self.kind_idx = k
                        k = k + 1
                    self.f_name.value      = ex[2]
                    self.f_trigger.value   = ex[3]
                    self.f_expansion.value = ex[4]
                    self.f_prec.value      = ex[5]
                    event.consume()
                    return
                i2 = i2 + 1

        # Delegate to text inputs
        self.f_name.handle_event(event)
        self.f_trigger.handle_event(event)
        self.f_expansion.handle_event(event)
        self.f_prec.handle_event(event)
        self.test_input.handle_event(event)

        # Refresh if version changed
        if lang_version() != self.reg_version:
            self._refresh_registry()

    def draw(self, renderer):
        if not self.visible: return

        var full_rect = Rect(self.x, self.y, self.w, self.h)
        renderer.fill_rect(full_rect, self.BG)
        renderer.draw_line(self.x, self.y, self.x + self.w, self.y, self.BORDER, 1)

        self._draw_form(renderer)
        self._draw_registry(renderer)
        self._draw_test(renderer)

        # Column dividers
        var div1 = self.x + self.FORM_W
        var div2 = div1 + self.REG_W
        renderer.draw_line(div1, self.y + 4, div1, self.y + self.h - 4, self.BORDER, 1)
        renderer.draw_line(div2, self.y + 4, div2, self.y + self.h - 4, self.BORDER, 1)

    def _draw_form(self, renderer):
        var x = self.x + self.PAD
        var y = self.y + 6

        renderer.draw_text("DEFINE EXTENSION", x, y, self.F_BOLD, self.ACCENT)

        # Kind selector tabs
        var kind_y = self.y + 22
        var kw = 72
        var i = 0
        while i < len(self.kind_options):
            var bx   = x + i * (kw + 4)
            var is_active = (i == self.kind_idx)
            var bg   = Color(99, 102, 241, is_active * 60)
            var tc   = self.ACCENT if is_active else self.DIM
            renderer.fill_rect(Rect(bx, kind_y, kw, 22), bg)
            renderer.draw_rect(Rect(bx, kind_y, kw, 22), Color(255, 255, 255, is_active * 30 + 8), 1)
            renderer.draw_text(self.kind_options[i], bx + 6, kind_y + 5, self.F_SMALL, tc)
            i = i + 1

        # Fields
        var fields = [
            ["name",              self.f_name],
            ["trigger / pattern", self.f_trigger],
            ["expansion / desc",  self.f_expansion],
            ["precedence",        self.f_prec]
        ]
        var fy = self.y + 48
        var fi = 0
        while fi < len(fields):
            renderer.draw_text(fields[fi][0], x, fy, self.F_SMALL, self.DIM)
            fields[fi][1].y = fy + 12
            fields[fi][1].draw(renderer)
            fy = fy + 50
            fi = fi + 1

        # Buttons row
        var btn_y = fy + 2
        renderer.fill_rect(Rect(x, btn_y, 90, 26), Color(99, 102, 241, 80))
        renderer.draw_rect(Rect(x, btn_y, 90, 26), Color(99, 102, 241, 120), 1)
        renderer.draw_text("Register", x + 16, btn_y + 7, self.F_BOLD, Color(200, 202, 255, 230))

        var clr_x = x + 100
        renderer.fill_rect(Rect(clr_x, btn_y, 70, 26), Color(255, 255, 255, 8))
        renderer.draw_rect(Rect(clr_x, btn_y, 70, 26), self.BORDER, 1)
        renderer.draw_text("Clear", clr_x + 16, btn_y + 7, self.F_SMALL, self.DIM)

        var rst_x = clr_x + 80
        renderer.fill_rect(Rect(rst_x, btn_y, 90, 26), Color(248, 113, 113, 30))
        renderer.draw_rect(Rect(rst_x, btn_y, 90, 26), Color(248, 113, 113, 60), 1)
        renderer.draw_text("Reset All", rst_x + 8, btn_y + 7, self.F_SMALL, Color(248, 113, 113, 180))

        # Status message
        if len(self.status_msg) > 0:
            var sc = self.OK if self.status_kind == "ok" else (self.WARN if self.status_kind == "warn" else self.ERR)
            renderer.draw_text(self.status_msg, x, btn_y + 34, self.F_SMALL, sc)

    def _draw_registry(self, renderer):
        var x  = self.x + self.FORM_W + self.PAD
        var y  = self.y + 6
        var rw = self.REG_W - self.PAD * 2

        renderer.draw_text("REGISTRY  v" + str(self.reg_version), x, y, self.F_BOLD, self.ACCENT)

        var row_y = self.y + 22
        var rh    = 16

        # Tokens section
        renderer.draw_text("? TOKENS  (" + str(len(self.reg_tokens)) + ")",
                           x, row_y, self.F_SMALL, self.TOK_CLR)
        row_y = row_y + rh
        var i = 0
        while i < len(self.reg_tokens):
            if row_y > self.y + self.h - 10: break
            var t   = self.reg_tokens[i]
            var pat = ""
            if len(t["pattern"]) > 0: pat = "  ~/" + t["pattern"] + "/"
            renderer.draw_text("  - " + t["name"] + pat,
                               x, row_y, self.F_BODY,
                               Color(self.TOK_CLR.r, self.TOK_CLR.g, self.TOK_CLR.b, 160))
            row_y = row_y + rh
            i = i + 1

        # Rules section
        renderer.draw_text("? RULES  (" + str(len(self.reg_rules)) + ")",
                           x, row_y, self.F_SMALL, self.RULE_CLR)
        row_y = row_y + rh
        i = 0
        while i < len(self.reg_rules):
            if row_y > self.y + self.h - 10: break
            var r     = self.reg_rules[i]
            var brief = "[" + r["kind"] + "] " + r["name"]
            if len(r["trigger"]) > 0:
                brief = brief + "  '" + r["trigger"] + "'"
            if r["kind"] == "rewrite" and len(r["expansion"]) > 0:
                var exp = r["expansion"]
                if len(exp) > 18: exp = exp[0:16] + "..."
                brief = brief + " -> " + exp
            renderer.draw_text("  - " + brief,
                               x, row_y, self.F_BODY,
                               Color(self.RULE_CLR.r, self.RULE_CLR.g, self.RULE_CLR.b, 160))
            row_y = row_y + rh
            i = i + 1

        # Operators section
        renderer.draw_text("? OPERATORS  (" + str(len(self.reg_ops)) + ")",
                           x, row_y, self.F_SMALL, self.OP_CLR)
        row_y = row_y + rh
        i = 0
        while i < len(self.reg_ops):
            if row_y > self.y + self.h - 10: break
            var o = self.reg_ops[i]
            renderer.draw_text("  - '" + o["symbol"] + "'  " + o["arity"] + "  prec=" + str(o["prec"]),
                               x, row_y, self.F_BODY,
                               Color(self.OP_CLR.r, self.OP_CLR.g, self.OP_CLR.b, 160))
            row_y = row_y + rh
            i = i + 1

        # Quick-examples hint
        if len(self.reg_tokens) == 0 and len(self.reg_rules) == 0:
            renderer.draw_text("(no extensions defined yet)", x + 8, self.y + 50,
                               self.F_SMALL, self.DIM)
            renderer.draw_text("Quick-start examples:", x + 8, self.y + 72, self.F_SMALL, self.DIM)
            var ei = 0
            while ei < len(self.examples):
                renderer.draw_text("  ? " + self.examples[ei][0],
                                   x + 8, self.y + 88 + ei * 16,
                                   self.F_SMALL, Color(self.ACCENT.r, self.ACCENT.g, self.ACCENT.b, 120))
                ei = ei + 1

    def _draw_test(self, renderer):
        var x  = self.x + self.FORM_W + self.REG_W + self.PAD
        var y  = self.y + 6
        var tw = self.TEST_W - self.PAD * 2

        renderer.draw_text("LIVE TEST", x, y, self.F_BOLD, self.ACCENT)
        renderer.draw_text("Code (with rewrites applied):", x, self.y + 22, self.F_SMALL, self.DIM)

        self.test_input.y = self.y + 34
        self.test_input.draw(renderer)

        # Run button
        renderer.fill_rect(Rect(x, self.y + 68, 80, 24), Color(99, 102, 241, 80))
        renderer.draw_rect(Rect(x, self.y + 68, 80, 24), Color(99, 102, 241, 120), 1)
        renderer.draw_text("> Run", x + 18, self.y + 75, self.F_BOLD, Color(200, 202, 255, 220))

        renderer.draw_text("Output:", x, self.y + 102, self.F_SMALL, self.DIM)
        var out_y = self.y + 118
        var i = 0
        while i < len(self.test_output):
            if out_y > self.y + self.h - 10: break
            var line = self.test_output[i]
            var clr  = self.TEXT
            if string_startswith(line, ">"):
                clr = Color(self.ACCENT.r, self.ACCENT.g, self.ACCENT.b, 200)
            renderer.draw_text(line, x, out_y, self.F_BODY, clr)
            out_y = out_y + 15
            i = i + 1

        if len(self.test_output) == 0:
            renderer.draw_text("Results appear here after > Run", x + 4, self.y + 122,
                               self.F_SMALL, self.DIM)
            renderer.draw_text("Example: unless x > 5:", x + 4, self.y + 142,
                               self.F_SMALL, Color(self.DIM.r, self.DIM.g, self.DIM.b, 100))
            renderer.draw_text("Example: [1,2,3] has 2", x + 4, self.y + 158,
                               self.F_SMALL, Color(self.DIM.r, self.DIM.g, self.DIM.b, 100))
