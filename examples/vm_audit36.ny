# vm_audit36.ny - EditorBuffer's operation-based undo/redo (ide_editor.ny).
#
# Round 71c: the IDE's undo used to snapshot the WHOLE document text on every
# keystroke (nython_ide.ny's old _push_undo/self.undo_stack). EditorBuffer now
# records a handful of scalars per character edit instead - see
# ide_editor.ny's _record_op/_apply_inverse, modelled on
# lib/gui_piecetable.ny's PieceTable.undo()/redo(). This pins the behaviour:
# undo/redo must reproduce the exact document and cursor position at every
# step, on both engines, for typing, backspacing (same-line and across a line
# boundary), newlines (with and without auto-indent), and the coarse
# push_snapshot() path used for multi-line edits.

import "ide_editor.ny"

var pass_n = 0
var fail_n = 0

def check(name, got, want):
    if got == want:
        pass_n = pass_n + 1
    else:
        fail_n = fail_n + 1
        print("FAIL " + name + ": got " + str(got) + " want " + str(want))

print("== typing then undo/redo ==")
var b = EditorBuffer("t.ny", "")
b.insert_char("h")
b.insert_char("i")
check("typed", b.get_all_text(), "hi")
check("cursor after typing", b.cursor_col, 2)
check("can_undo", b.can_undo(), true)
b.undo()
check("undo one char", b.get_all_text(), "h")
check("cursor after one undo", b.cursor_col, 1)
b.undo()
check("undo to empty", b.get_all_text(), "")
check("can_undo empty", b.can_undo(), false)
check("can_redo after undo", b.can_redo(), true)
b.redo()
check("redo one char", b.get_all_text(), "h")
b.redo()
check("redo second char", b.get_all_text(), "hi")
check("can_redo exhausted", b.can_redo(), false)

print("== new edit after undo clears the redo stack ==")
var b2 = EditorBuffer("t2.ny", "ab")
b2.cursor_col = 2
b2.insert_char("c")
check("b2 typed", b2.get_all_text(), "abc")
b2.undo()
check("b2 undone", b2.get_all_text(), "ab")
check("b2 can_redo before new edit", b2.can_redo(), true)
b2.cursor_col = 2
b2.insert_char("z")
check("b2 branched", b2.get_all_text(), "abz")
check("b2 redo stack cleared", b2.can_redo(), false)

print("== backspace same line, then undo ==")
var b3 = EditorBuffer("t3.ny", "abc")
b3.cursor_col = 3
b3.delete_char_back()
check("b3 backspaced", b3.get_all_text(), "ab")
check("b3 cursor", b3.cursor_col, 2)
b3.undo()
check("b3 undo backspace", b3.get_all_text(), "abc")
check("b3 cursor restored", b3.cursor_col, 3)

print("== backspace across a line boundary, then undo/redo ==")
var b4 = EditorBuffer("t4.ny", "foo\nbar")
b4.cursor_row = 1
b4.cursor_col = 0
b4.delete_char_back()
check("b4 line_count after join", b4.line_count, 1)
check("b4 joined text", b4.get_all_text(), "foobar")
check("b4 cursor row", b4.cursor_row, 0)
check("b4 cursor col", b4.cursor_col, 3)
b4.undo()
check("b4 line_count restored", b4.line_count, 2)
check("b4 text restored", b4.get_all_text(), "foo\nbar")
check("b4 cursor restored", b4.cursor_row, 1)
b4.redo()
check("b4 redo rejoins", b4.get_all_text(), "foobar")

print("== newline without auto-indent, then undo ==")
var b5 = EditorBuffer("t5.ny", "abcd")
b5.cursor_col = 2
b5.insert_newline()
check("b5 line_count after split", b5.line_count, 2)
check("b5 line 0", b5.get_line(0), "ab")
check("b5 line 1", b5.get_line(1), "cd")
check("b5 cursor row", b5.cursor_row, 1)
check("b5 cursor col", b5.cursor_col, 0)
b5.undo()
check("b5 rejoined", b5.get_all_text(), "abcd")
check("b5 line_count restored", b5.line_count, 1)
check("b5 cursor restored row", b5.cursor_row, 0)
check("b5 cursor restored col", b5.cursor_col, 2)

print("== newline with auto-indent after a colon, then undo/redo ==")
var b6 = EditorBuffer("t6.ny", "if true:")
b6.cursor_col = 8
b6.insert_newline()
check("b6 line 1 padded", b6.get_line(1), "    ")
check("b6 cursor col is indent", b6.cursor_col, 4)
b6.undo()
check("b6 rejoined exactly (pad stripped)", b6.get_all_text(), "if true:")
check("b6 line_count back to one", b6.line_count, 1)
b6.redo()
check("b6 redo respawns the pad", b6.get_line(1), "    ")

print("== push_snapshot for a coarse multi-line edit, then undo/redo ==")
var b7 = EditorBuffer("t7.ny", "one\ntwo\nthree")
b7.cursor_row = 1
b7.cursor_col = 0
b7.push_snapshot()
# Simulate a bulk edit (e.g. cut_line) done outside EditorBuffer's own
# methods, exactly as nython_ide.ny's cut/paste/comment-toggle do.
b7.lines = ["one", "three"]
b7.line_count = 2
check("b7 after bulk edit", b7.get_all_text(), "one\nthree")
b7.undo()
check("b7 snapshot undo restores text", b7.get_all_text(), "one\ntwo\nthree")
check("b7 snapshot undo restores cursor row", b7.cursor_row, 1)
b7.redo()
check("b7 snapshot redo re-applies", b7.get_all_text(), "one\nthree")

print("== mixed sequence: type, snapshot bulk edit, type, undo x3 ==")
var b8 = EditorBuffer("t8.ny", "x")
b8.cursor_col = 1
b8.insert_char("y")
check("b8 step1", b8.get_all_text(), "xy")
b8.push_snapshot()
b8.lines = ["XY"]
b8.line_count = 1
check("b8 step2 bulk", b8.get_all_text(), "XY")
b8.cursor_col = 2
b8.insert_char("z")
check("b8 step3", b8.get_all_text(), "XYz")
b8.undo()
check("b8 undo3", b8.get_all_text(), "XY")
b8.undo()
check("b8 undo2 (snapshot)", b8.get_all_text(), "xy")
b8.undo()
check("b8 undo1", b8.get_all_text(), "x")
check("b8 exhausted", b8.can_undo(), false)

print("Results: " + str(pass_n) + " passed, " + str(fail_n) + " failed")
if fail_n == 0:
    print("=== VM_AUDIT36 PASSED ===")
else:
    print("=== VM_AUDIT36 FAILED ===")
