@echo off
setlocal enabledelayedexpansion

echo.
echo ============================================================
echo  Nython Windows Build Script
echo ============================================================
echo.

:: ── 1. Compiler ──────────────────────────────────────────────────────────────
where g++ >nul 2>&1
if errorlevel 1 (
    echo [ERROR] g++ not found on PATH.
    echo         Install w64devkit or MinGW-w64 and add its bin folder to PATH.
    goto :fail
)
for /f "tokens=*" %%i in ('g++ --version 2^>^&1 ^| findstr /n "." ^| findstr "^1:"') do set GCC_VER=%%i
echo [OK] Compiler: !GCC_VER!

:: ── 2. SDL3 headers ──────────────────────────────────────────────────────────
if not exist "C:\SDL3\include\SDL3\SDL.h" (
    echo [ERROR] C:\SDL3\include\SDL3\SDL.h not found.
    echo         Download SDL3-devel-x.x.x-mingw.zip from:
    echo           https://github.com/libsdl-org/SDL/releases
    echo         Extract x86_64-w64-mingw32 folder contents to C:\SDL3\
    goto :fail
)
echo [OK] SDL3 headers found
if not exist "C:\SDL3\include\SDL3_ttf\SDL_ttf.h" (
    echo [ERROR] SDL3_ttf headers missing at C:\SDL3\include\SDL3_ttf\
    goto :fail
)
echo [OK] SDL3_ttf headers found
if not exist "C:\SDL3\include\SDL3_image\SDL_image.h" (
    echo [ERROR] SDL3_image headers missing at C:\SDL3\include\SDL3_image\
    goto :fail
)
echo [OK] SDL3_image headers found

:: ── 3. Locate SDL3 library files ─────────────────────────────────────────────
set "SDL3_LIB="
set "SDL3_TTF_LIB="
set "SDL3_IMG_LIB="

if exist "C:\SDL3\lib\libSDL3.dll.a"       set "SDL3_LIB=C:\SDL3\lib\libSDL3.dll.a"
if exist "C:\SDL3\lib\libSDL3_ttf.dll.a"   set "SDL3_TTF_LIB=C:\SDL3\lib\libSDL3_ttf.dll.a"
if exist "C:\SDL3\lib\libSDL3_image.dll.a" set "SDL3_IMG_LIB=C:\SDL3\lib\libSDL3_image.dll.a"

if not defined SDL3_LIB     if exist "C:\SDL3\lib\libSDL3.a"       set "SDL3_LIB=C:\SDL3\lib\libSDL3.a"
if not defined SDL3_TTF_LIB if exist "C:\SDL3\lib\libSDL3_ttf.a"   set "SDL3_TTF_LIB=C:\SDL3\lib\libSDL3_ttf.a"
if not defined SDL3_IMG_LIB if exist "C:\SDL3\lib\libSDL3_image.a" set "SDL3_IMG_LIB=C:\SDL3\lib\libSDL3_image.a"

if not defined SDL3_LIB (
    echo [ERROR] No SDL3 library found in C:\SDL3\lib\
    echo         Expected: libSDL3.dll.a
    dir "C:\SDL3\lib\" 2>nul
    goto :fail
)
echo [OK] SDL3 lib:     !SDL3_LIB!
echo [OK] SDL3_ttf lib: !SDL3_TTF_LIB!
echo [OK] SDL3_img lib: !SDL3_IMG_LIB!

:: Verify SDL_Init symbol is in the library
where nm >nul 2>&1
if not errorlevel 1 (
    nm "!SDL3_LIB!" 2>nul | findstr /i "SDL_Init" >nul
    if not errorlevel 1 (
        echo [OK] SDL3 library verified ^(SDL_Init found^)
    ) else (
        echo [WARN] SDL_Init not found in library - wrong architecture?
        echo        Use x86_64-w64-mingw32 folder from the MinGW zip.
    )
)

if exist "C:\SDL3\bin\SDL3.dll" (
    echo [OK] SDL3 DLLs found at C:\SDL3\bin\
) else (
    echo [WARN] C:\SDL3\bin\SDL3.dll not found - copy DLLs manually later
)

:: ── 4. Prepare output directories ────────────────────────────────────────────
echo.
echo Building Nython...
echo.
if not exist "bin\Release" mkdir "bin\Release"
if not exist "obj"         mkdir "obj"

:: Compiler flags (no -mwindows so console output is visible for diagnostics)
set "CXXFLAGS=-std=c++20 -O2 -Wall -Wno-misleading-indentation -Wno-unused-but-set-variable -Wno-unused-function -Wno-cpp -Wno-overloaded-virtual -march=x86-64 -fno-strict-aliasing -fwrapv -fno-delete-null-pointer-checks -Iinclude -IC:\SDL3\include -DNYTHON_WITH_IDE=1 -DSDL_MAIN_HANDLED=1 -D_WIN32_WINNT=0x0600"

:: ── 5. Compile all sources ────────────────────────────────────────────────────
set "COMPILE_OK=1"

for %%f in (src\*.cpp) do (
    echo   Compiling %%f...
    g++ !CXXFLAGS! -c "%%f" -o "obj\%%~nf.o"
    if errorlevel 1 (
        echo   [FAIL] %%f
        set "COMPILE_OK=0"
    )
)

for %%f in (src\builtins\*.cpp) do (
    echo   Compiling %%f...
    g++ !CXXFLAGS! -c "%%f" -o "obj\%%~nf.o"
    if errorlevel 1 (
        echo   [FAIL] %%f
        set "COMPILE_OK=0"
    )
)

if not "!COMPILE_OK!"=="1" (
    echo.
    echo [ERROR] One or more files failed to compile.
    goto :fail
)

:: ── 6. Create object file list and link ──────────────────────────────────────
if exist "obj\objects.rsp" del "obj\objects.rsp"
for %%f in (obj\*.o) do echo "%%f">> "obj\objects.rsp"

echo   Linking...
g++ -o "bin\Release\nython.exe" @"obj\objects.rsp" "!SDL3_LIB!" "!SDL3_TTF_LIB!" "!SDL3_IMG_LIB!" -lws2_32

if errorlevel 1 (
    echo.
    echo [ERROR] Linking failed. See errors above.
    goto :fail
)
echo [OK] Built: bin\Release\nython.exe

:: ── 7. Copy ALL DLLs from C:\SDL3\bin\ ───────────────────────────────────────
:: Copies every .dll including freetype, harfbuzz, libpng etc. that SDL3_ttf/image need.
:: Missing any dependency DLL causes a silent crash before any code runs.
set "OUTDIR=bin\Release"

if exist "C:\SDL3\bin\" (
    echo   Copying all DLLs from C:\SDL3\bin\ ...
    for %%d in ("C:\SDL3\bin\*.dll") do (
        if not exist "!OUTDIR!\%%~nxd" (
            copy "%%d" "!OUTDIR!\" >nul
            echo [OK] Copied %%~nxd
        )
    )
) else (
    echo [WARN] C:\SDL3\bin\ not found - copy SDL3.dll etc. to !OUTDIR!\ manually
)

:: Copy Nython runtime files
:: Copy helper batch scripts next to nython.exe for easy access
for %%b in (run_gui_tests.bat diagnose.bat) do (
    if exist "%%b" if not exist "!OUTDIR!\%%b" (
        copy "%%b" "!OUTDIR!\" >nul 2>&1
        echo [OK] Copied %%b
    )
)
if not exist "!OUTDIR!\nython_ide.ny" (
    copy "nython_ide.ny" "!OUTDIR!\" >nul 2>&1
    echo [OK] Copied nython_ide.ny
)
if not exist "!OUTDIR!\lib" (
    xcopy /e /q /y lib "!OUTDIR!\lib\" >nul 2>&1
    echo [OK] Copied lib\
)
if exist "examples" (
    if not exist "!OUTDIR!\examples" (
        xcopy /e /q /y examples "!OUTDIR!\examples\" >nul 2>&1
        echo [OK] Copied examples\
    )
)

:: ── 8. Done ───────────────────────────────────────────────────────────────────
echo.
echo ============================================================
echo  Build complete!
echo  Output: !OUTDIR!\nython.exe
echo.
echo  HOW TO RUN - open a new cmd.exe window then:
echo    cd "!CD!\!OUTDIR!"
echo    nython.exe
echo.
echo  DIAGNOSTIC - to test SDL3 without the IDE:
echo    nython.exe examples\check_sdl.ny
echo ============================================================
echo.
goto :end

:fail
echo.
echo ============================================================
echo  Build failed. See SDL3_SETUP.md for full setup guide.
echo ============================================================
echo.
exit /b 1

:end
exit /b 0
