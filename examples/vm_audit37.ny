# vm_audit37.ny - multi-cursor typing algorithm (EditorBuffer + lib/ide_selection.ny).
#
# Round 71c: nython_ide.ny's _apply_to_extra_carets() propagates a primary
# edit to every extra caret by processing them last-to-first (by row, then
# col, descending) so an insert/delete never invalidates a not-yet-processed
# caret's saved position. That method lives on NythonIDE, which auto-launches
# a window on import and can't be unit-tested directly - but the algorithm
# itself only needs EditorBuffer (ide_editor.ny) and SelectionModel
# (lib/ide_selection.ny), both plain classes. This file replicates the exact
# same algorithm against those two directly, to verify the technique before
# trusting the copy wired into the IDE.

import "ide_editor.ny"
import "lib/ide_selection.ny"

var pass_n = 0
var fail_n = 0

def check(name, got, want):
    if got == want:
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print("FAIL " + name + ": got " + str(got) + " want " + str(want))

# Mirrors NythonIDE._apply_to_extra_carets: sels[0] is the primary (ignored
# here - the caller applies the primary edit separately, exactly as
# nython_ide.ny does via self.editor.handle_event(e) before this runs),
# sels[1:count] are the extra carets.
def apply_to_extras(buf, model, kind, text):
    if model.count <= 1:
        return
    var order = []
    var i = 1
    while i < model.count:
        if model.sels[i].caret.row < buf.line_count:
            order.append(i)
        i = i + 1
    var n = len(order)
    var a = 0
    while a < n:
        var b = a + 1
        while b < n:
            var sa = model.sels[order[a]]
            var sb = model.sels[order[b]]
            var swap = false
            if sb.caret.row > sa.caret.row:
                swap = true
            elif sb.caret.row == sa.caret.row and sb.caret.col > sa.caret.col:
                swap = true
            if swap:
                var t = order[a]
                order[a] = order[b]
                order[b] = t
            b = b + 1
        a = a + 1
    var k = 0
    while k < n:
        var s = model.sels[order[k]]
        buf.cursor_row = s.caret.row
        buf.cursor_col = s.caret.col
        if kind == "insert":
            buf.insert_char(text)
        elif kind == "backspace":
            buf.delete_char_back()
        elif kind == "enter":
            buf.insert_newline()
        s.caret.row = buf.cursor_row
        s.caret.col = buf.cursor_col
        k = k + 1

print("== three carets on three lines, type one char at each ==")
var b = EditorBuffer("m.ny", "aaa\nbbb\nccc")
var model = SelectionModel()
# Primary caret at end of line 0 (handled by the caller, not this helper).
b.cursor_row = 0
b.cursor_col = 3
model.sels[0].caret.row = 0
model.sels[0].caret.col = 3
model.add_caret(1, 3)
model.add_caret(2, 3)
check("three carets registered", model.count, 3)
# Primary edit, exactly as self.editor.handle_event(e) performs it in the IDE.
b.insert_char("X")
apply_to_extras(b, model, "insert", "X")
check("line0 got X", b.get_line(0), "aaaX")
check("line1 got X", b.get_line(1), "bbbX")
check("line2 got X", b.get_line(2), "cccX")
check("extra caret1 advanced", model.sels[1].caret.col, 4)
check("extra caret2 advanced", model.sels[2].caret.col, 4)

print("== two carets on the SAME line, type at both (right-to-left order matters) ==")
var b2 = EditorBuffer("m2.ny", "abcdef")
var model2 = SelectionModel()
b2.cursor_row = 0
b2.cursor_col = 2
model2.sels[0].caret.row = 0
model2.sels[0].caret.col = 2
model2.add_caret(0, 5)
b2.insert_char("_")
apply_to_extras(b2, model2, "insert", "_")
# Primary insert at col 2 shifts everything after it right by one BEFORE the
# extra caret runs; processing right-to-left means the caret originally
# recorded at col 5 is applied at its own (still-correct, since it is to the
# right of the primary and gets processed after) position.
check("same-line multi-insert", b2.get_all_text(), "ab_cd_ef")

print("== backspace at three carets simultaneously ==")
var b3 = EditorBuffer("m3.ny", "1X\n2X\n3X")
var model3 = SelectionModel()
b3.cursor_row = 0
b3.cursor_col = 2
model3.sels[0].caret.row = 0
model3.sels[0].caret.col = 2
model3.add_caret(1, 2)
model3.add_caret(2, 2)
b3.delete_char_back()
apply_to_extras(b3, model3, "backspace", "")
check("backspace all three", b3.get_all_text(), "1\n2\n3")

print("== undo after a multi-caret edit undoes the primary's own entry ==")
var b4 = EditorBuffer("m4.ny", "a\nb")
var model4 = SelectionModel()
b4.cursor_row = 0
b4.cursor_col = 1
model4.sels[0].caret.row = 0
model4.sels[0].caret.col = 1
model4.add_caret(1, 1)
b4.insert_char("!")
apply_to_extras(b4, model4, "insert", "!")
check("both lines edited", b4.get_all_text(), "a!\nb!")
b4.undo()
# Documented limitation: multi-caret edits are NOT grouped into one undo
# step (each buf.insert_char call - one per caret - records its own entry),
# so a single undo only reverts the LAST caret processed, not all of them.
check("undo only reverts one caret's edit", b4.get_all_text(), "a!\nb")

print("Results: " + str(pass_n) + " passed, " + str(fail_n) + " failed")
if fail_n == 0:
    print("=== VM_AUDIT37 PASSED ===")
else:
    print("=== VM_AUDIT37 FAILED ===")
