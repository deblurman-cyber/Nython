@echo off
setlocal enabledelayedexpansion

echo.
echo ============================================================
echo  Nython SDL3 Diagnostics
echo ============================================================
echo.

:: Auto-find nython.exe
set "NYTHON="
if exist "nython.exe"             set "NYTHON=nython.exe"
if exist "bin\Release\nython.exe" set "NYTHON=bin\Release\nython.exe"
if exist "bin\Debug\nython.exe"   set "NYTHON=bin\Debug\nython.exe"

if "!NYTHON!"=="" (
    echo [ERROR] nython.exe not found. Run build_windows.bat first.
    pause & exit /b 1
)
echo [OK] Using: !NYTHON!
echo.

:: Check DLLs
echo Checking DLLs...
for %%f in (SDL3.dll SDL3_ttf.dll SDL3_image.dll) do (
    set "FOUND="
    if exist "%%f"                set "FOUND=current dir"
    if exist "bin\Release\%%f"    set "FOUND=bin\Release"
    if exist "bin\Debug\%%f"      set "FOUND=bin\Debug"
    if defined FOUND (
        echo [OK] %%f  ^(!FOUND!^)
    ) else (
        echo [MISS] %%f not found - copy from C:\SDL3\bin\
    )
)
echo.

:: Check runtime files
echo Checking runtime files...
set "RTDIR="
if exist "nython_ide.ny"             set "RTDIR=."
if exist "bin\Release\nython_ide.ny" set "RTDIR=bin\Release"
if exist "bin\Debug\nython_ide.ny"   set "RTDIR=bin\Debug"

if defined RTDIR (
    echo [OK] nython_ide.ny  ^(!RTDIR!^)
) else (
    echo [MISS] nython_ide.ny not found
)
if exist "lib\gui.ny"             echo [OK] lib\gui.ny
if exist "bin\Release\lib\gui.ny" echo [OK] bin\Release\lib\gui.ny
echo.

:: Auto-find examples
set "EXAMPLES="
if exist "examples\gui_tests\test_01_sdl_init.ny"             set "EXAMPLES=examples"
if exist "bin\Release\examples\gui_tests\test_01_sdl_init.ny" set "EXAMPLES=bin\Release\examples"

:: Run SDL3 version check
echo Running SDL3 check...
if defined EXAMPLES (
    "!NYTHON!" "!EXAMPLES!\gui_tests\test_01_sdl_init.ny"
) else (
    "!NYTHON!" --console
)
echo.
echo Exit code: %errorlevel%
echo.
pause
