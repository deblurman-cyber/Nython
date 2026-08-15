@echo off
setlocal enabledelayedexpansion

echo.
echo ============================================================
echo  Nython GUI Integration Tests
echo ============================================================
echo.

:: Auto-find nython.exe (works from project root OR bin\Release\)
set "NYTHON="
if exist "nython.exe"           set "NYTHON=nython.exe"
if exist "bin\Release\nython.exe" set "NYTHON=bin\Release\nython.exe"
if exist "bin\Debug\nython.exe"   set "NYTHON=bin\Debug\nython.exe"

if "!NYTHON!"=="" (
    echo [ERROR] nython.exe not found.
    echo         Run build_windows.bat first.
    pause & exit /b 1
)
echo [OK] Using: !NYTHON!

:: Auto-find examples folder
set "EXAMPLES="
if exist "examples\gui_tests\test_01_sdl_init.ny"         set "EXAMPLES=examples"
if exist "bin\Release\examples\gui_tests\test_01_sdl_init.ny" set "EXAMPLES=bin\Release\examples"
if exist "bin\Debug\examples\gui_tests\test_01_sdl_init.ny"   set "EXAMPLES=bin\Debug\examples"

if "!EXAMPLES!"=="" (
    echo [ERROR] examples\gui_tests\ not found.
    pause & exit /b 1
)
echo [OK] Tests at: !EXAMPLES!\gui_tests\
echo.

set "TOTAL=0"
set "FAIL_AT="

for %%t in (
    test_01_sdl_init
    test_02_window
    test_03_eventloop
    test_04_drawing
    test_05_font_after_window
    test_05b_draw_text_only
    test_06_import
    test_07_window_class
    test_08_window_create
    test_09_run_empty
    test_10_font_in_run
) do (
    set /a TOTAL+=1
    echo ── %%t ──────────────────────────────────────────────────
    "!NYTHON!" "!EXAMPLES!\gui_tests\%%t.ny"
    if errorlevel 1 (
        echo.
        echo *** CRASHED: %%t ***
        set "FAIL_AT=%%t"
        goto :done
    )
    echo.
)

:done
echo.
echo ============================================================
if "!FAIL_AT!"=="" (
    echo  All !TOTAL! tests passed.
) else (
    echo  CRASHED at: !FAIL_AT!
    echo  That test contains the GUI bug.
)
echo ============================================================
echo.
pause
