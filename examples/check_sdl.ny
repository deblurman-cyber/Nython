# check_sdl.ny — Verify SDL3 is installed and the GUI backend is functional.
# Run from the same folder as nython.exe:  nython.exe examples/check_sdl.ny

print "=== Nython SDL3 Check ==="
print ""

# 1. SDL3 runtime version
var ver = gui_sdl_version()
if ver != none and ver != "":
    print "✓ SDL3 runtime version: " + str(ver)
else:
    print "✗ SDL3 version unavailable — SDL3.dll may be missing or wrong architecture"

# 2. Try to detect any pre-existing error
var err = gui_get_error()
if err != none and err != "":
    print "✗ Existing SDL error: " + str(err)
else:
    print "✓ No SDL errors pending"

print ""
print "If the IDE fails to open, run from cmd.exe to see the full error:"
print "  cd <nython_folder>"
print "  nython.exe"
print ""
print "Checklist:"
print "  SDL3.dll         — must be next to nython.exe"
print "  SDL3_ttf.dll     — must be next to nython.exe"
print "  SDL3_image.dll   — must be next to nython.exe"
print "  nython_ide.ny    — must be next to nython.exe"
print "  lib/             — must be next to nython.exe"
