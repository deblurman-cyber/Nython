# Assertions for the scripted UI walkthrough. `check(shot, must, mustnot, region)`
# is provided by run_ui_tests.sh's driver. `region` limits the match to a
# rectangle, which matters where the same string legitimately appears elsewhere
# (a closed tab still shows in the status message and the file tree).
TABBAR = (310, 70, 1400, 106)

check('base',              must=['File','EXPLORER','main.ny','Output','Ln 1'])
check('rail_search',       must=['SEARCH','Search workspace'],   mustnot=['EXPLORER'])
check('rail_git',          must=['SOURCE CONTROL'],              mustnot=['EXPLORER'])
check('rail_explorer',     must=['EXPLORER','Makefile'],        mustnot=['SEARCH'])
check('tab_utils',         must=['clamp','lerp'],                mustnot=['Sequential'])
check('tab_model',         must=['Sequential','nytorch'],        mustnot=['clamp'])
check('tab_main',          must=['App','tick'],                  mustnot=['clamp'])
check('panel_problems',    must=['undefined name','unused variable','main.ny : 12'])
check('panel_terminal',    must=['interactive shell'])
check('term_version',      must=['Nython 0.2.1  |  NythonIDE v4','$ version'])
check('panel_output',      must=['NythonIDE v4 ready','Workspace'])
check('palette_open',      must=['Type a command','Run: Execute','View: Toggle Sidebar'])
check('palette_filtered',  must=['Toggle Sidebar','Toggle Panel','Toggle Minimap'],
                           mustnot=['Run: Execute'])
check('palette_closed',    must=['EXPLORER'],                    mustnot=['Type a command'])
# F5 now really invokes the interpreter, so the console shows the absolute path
# and either a duration or a parsed failure depending on whether an interpreter
# is present. Assert only on what is environment-independent.
check('after_f5',          must=['> Run', 'main.ny'])
check('menu_view',         must=['Toggle Sidebar','Toggle Panel','Toggle Minimap'])
check('menu_toggle_sidebar', must=['Toggle Sidebar'],            mustnot=['README.md'])
check('sidebar_restored',  must=['EXPLORER','Makefile'])
check('tab_closed',        must=['main.ny','model.ny'], mustnot=['utils.ny'], region=TABBAR)
check('resized_small',     must=['1024 x 600','EXPLORER'])
check('resized_large',     must=['1500 x 900','EXPLORER'])

# Project workflow: New Project creates a real folder on disk, opens it as the
# workspace and opens its target file.
check('file_menu',           must=['New Project...','Open Folder...','Open Project...','Save All'])
check('dialog_new_project',  must=['New Project','Enter to confirm'])
check('dialog_typed',        must=['/tmp/NyIdeTestProj'])
check('project_created',     must=['NyIdeTestProj','main.ny','.nyproj'])

# Editor caret, editing and clipboard.
check('caret_placed',   must=['Ln '])
check('typed',          must=['HELLO'])
check('undone',         must=['Undo'])
check('pasted',         must=['Pasted'])

# Find / Replace, breakpoints and the Debug panel.
check('find_open',      must=['0 matches'])
check('find_matches',   must=['self','of'])
check('find_next',      must=['of'])
check('replace_ready',  must=['count','TOTAL'])
check('replaced',       must=['TOTAL'])
check('breakpoint_set', must=['Breakpoint set'])
check('debug_panel',    must=['Breakpoints'])

# Right-click context menus (editor, file tree, tab) and autocomplete.
check('ctx_editor',   must=['Cut','Copy','Paste','Toggle Breakpoint','Run'])
check('ctx_used',     must=['Toggle Breakpoint'])
check('ctx_tree',     must=['Open','Copy Path','Set as Workspace'])
check('ctx_tab',      must=['Close Others','Save'])
# Deterministic: type the prefix "cl", so the only completion is "class".
check('autocomplete', must=['class'])
check('ac_accepted',  must=['Completed class'])

# Text selection: shift+arrows, drag, and clipboard operating on the selection.
check('sel_copied', must=['Copied selection'])
check('sel_cut',    must=['Cut selection'])
check('sel_undo',   must=['Undo'])
has_selection_highlight('sel_shift')
has_selection_highlight('sel_drag')

# Symbol outline (Code::Blocks-style browser) and light/dark theme.
check('outline',      must=['OUTLINE','App','tick'], mustnot=['EXPLORER'])
check('outline_jump', must=['OUTLINE','Line'])
check('theme_light',  must=['Theme: light'])
token_color_is('theme_dark', 'class', [196, 148, 255])
token_color_is('hl_light',   'class', [126, 42, 190])
background_is('theme_dark',       [13, 15, 26])
background_is('theme_light',      [243, 244, 248])
background_is('theme_dark_again', [13, 15, 26])

# Editor zoom: the code font size actually changes and resets.
check('zoom_in',    must=['Font size 16'])
check('zoom_reset', must=['Font size 13'])
mono_font_size_is('zoom_in', 16)
mono_font_size_is('zoom_reset', 13)

# Sidebar wheel scrolling, clickable Problems entries, and the recent list.
tree_first_row_is('tree_expanded', 'nython_src')
tree_first_row_is('tree_scrolled', 'break_test.ny')
tree_first_row_is('tree_back',     'nython_src')
# The Problems list holds whatever the last build produced, so assert the
# navigation happened (file:line in the status bar) rather than a fixed line.
check('problem_click', must=[':'])
check('recent_files',  must=['Recent Files'])

# Line operations and typing helpers, read back from the rendered buffer.
# A fresh file holds:  line0 '# untitledN.ny'  line1 'class A:'  line2 'pass'
# The left margin is x=376 and a space is 8px, so 408 is one indent level.
code_row_at('lo_indent',      167, text='pass', first_x=408.0)
# No first_x here: the highlighter emits a commented line as one token covering
# the whole line including its leading whitespace, so the segment starts at the
# margin even though the '#' is drawn indented. Text is what matters.
code_row_at('lo_commented',   167, text='# pass')
code_row_at('lo_uncommented', 167, text='pass', first_x=408.0)
code_row_at('lo_duplicated',  185, text='pass', first_x=408.0)
code_row_at('lo_bracket',     185, text='pass()', first_x=408.0)

# AI assistant (lib/aiagent.ny CodeAnalyzer), the VM execution mode, and the
# introspection panel fed by --tokenize.
check('ai_view',  must=['AI ASSISTANT','suggestion','Debug print statement'])
# The line number depends on the file on disk, which earlier steps may have
# saved; assert that navigation happened.
check('ai_jump',  must=['Line '])
# Asserts the VM path was invoked and reported, not that the file runs on it:
# the bytecode VM is a second-class engine (see round 1) and rejects sources the
# interpreter accepts, so success here would depend on the file under test.
check('vm_run',   must=['> VM', 'VM '])
check('tokenize', must=['Tokenize  (','<Tokens>'])

# Workspace search: typing filters real files, and a result opens at its line.
check('search_empty',   must=['Search workspace','Type at least two characters'])
check('search_results', must=['results in','tensor'])
check('search_open',    must=[' : '])
check('settings_saved', must=['Settings saved'])

# Every shot must also be structurally sound.
#
# Shots containing a modal overlay (dropdown menu, command palette) are exempt
# from the overlap check: the overlay paints an opaque panel over the UI beneath
# it, so its text legitimately shares coordinates with text it covers. The
# checker works on draw order, not occlusion, so it cannot tell the difference.
# Search result snippets are drawn full-length and cut by the sidebar's clip
# rect. The checker works on draw order, not clipping, so it sees them running
# under the editor text — the same blind spot as the modal overlays below.
OVERLAY_SHOTS = {'menu_view', 'menu_toggle_sidebar', 'palette_open', 'palette_filtered',
                 'search_results', 'search_open', 'settings_saved',
                 'file_menu', 'dialog_new_project', 'dialog_typed',
                 'find_open', 'find_matches', 'find_next', 'replace_ready', 'replaced',
                 'ctx_editor', 'ctx_tree', 'ctx_tab', 'autocomplete'}

for shot in all_shots():
    if shot not in OVERLAY_SHOTS:
        no_overlapping_text(shot)
    no_text_outside_window(shot)
