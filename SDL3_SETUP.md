# SDL3 GUI Setup Guide — NythonIDE

## Overview

NythonIDE uses SDL3 + SDL3_ttf + SDL3_image for its graphical interface.
SDL3 is always compiled in. If the DLLs are present and correct, the IDE
opens automatically when you run `nython.exe` with no arguments.

---

## Windows 11 — Complete Setup Checklist

### Step 1: Download SDL3 Development Libraries (MinGW versions)

Go to each releases page and download the **MinGW** development zip
(the filenames contain `mingw`, not `VC`):

| Library    | URL                                                   | File to download                   |
|------------|-------------------------------------------------------|------------------------------------|
| SDL3       | https://github.com/libsdl-org/SDL/releases            | SDL3-devel-X.X.X-mingw.zip         |
| SDL3_ttf   | https://github.com/libsdl-org/SDL_ttf/releases        | SDL3_ttf-devel-X.X.X-mingw.zip     |
| SDL3_image | https://github.com/libsdl-org/SDL_image/releases      | SDL3_image-devel-X.X.X-mingw.zip   |

> IMPORTANT: Download the x86_64 (64-bit) MinGW versions.
> Do NOT use the VC (Visual C++) zips — those are for MSVC, not MinGW.

### Step 2: Extract to C:\SDL3\

Inside each zip you will find an x86_64-w64-mingw32 folder.
Copy its contents into C:\SDL3\ so the structure is:

    C:\SDL3\
    ├── include\
    │   ├── SDL3\           <- SDL3 headers (SDL.h, SDL_video.h, ...)
    │   ├── SDL3_ttf\       <- SDL3_ttf headers (SDL_ttf.h)
    │   └── SDL3_image\     <- SDL3_image headers (SDL_image.h)
    ├── lib\
    │   ├── libSDL3.dll.a      <- MinGW import lib
    │   ├── libSDL3_ttf.dll.a
    │   └── libSDL3_image.dll.a
    └── bin\
        ├── SDL3.dll
        ├── SDL3_ttf.dll
        └── SDL3_image.dll

### Step 3: Copy the 3 DLLs next to nython.exe  ← MOST COMMONLY MISSED

The DLLs MUST be in the SAME folder as nython.exe:

    your_folder\
    ├── nython.exe
    ├── SDL3.dll           <- REQUIRED
    ├── SDL3_ttf.dll       <- REQUIRED
    ├── SDL3_image.dll     <- REQUIRED
    ├── nython_ide.ny
    └── lib\

Copy them from C:\SDL3\bin\ to the folder containing nython.exe.

### Step 4: Build in Code::Blocks

1. Open nython.cbp in Code::Blocks
2. Select Release target
3. Build -> Clean, then Build -> Build
4. Binary goes to bin\Release\nython.exe

### Step 5: Run

Double-click nython.exe — the IDE opens automatically.
Or from terminal: nython.exe (no args = IDE)

---

## Windows 11 — Troubleshooting

Run from cmd.exe to see the actual error:
    cd path\to\nython_folder
    nython.exe

Common errors:

  "SDL3.dll not found"           -> Copy SDL3.dll next to nython.exe
  "SDL3_ttf.dll not found"       -> Copy SDL3_ttf.dll next to nython.exe
  "SDL3_image.dll not found"     -> Copy SDL3_image.dll next to nython.exe
  "No available video device"    -> Update graphics drivers (DirectX 11+ required)
  Window flashes then closes     -> lib/ folder missing or nython_ide.ny not found
  Blank window                   -> nython_ide.ny not next to nython.exe

Check all 3 DLLs are present:
    where SDL3.dll
    where SDL3_ttf.dll
    where SDL3_image.dll

All three must resolve to the nython folder.

If you see MSVCP140.dll errors, install Visual C++ Redistributable:
    https://aka.ms/vs/17/release/vc_redist.x64.exe

---

## Linux

    sudo apt install libsdl3-dev libsdl3-ttf-dev libsdl3-image-dev
    make clean && make
    ./build/nython --ide

If SDL3 is not in apt yet, build from source:
    git clone --depth=1 -b release-3.2.x https://github.com/libsdl-org/SDL.git
    cd SDL && cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j$(nproc) && sudo cmake --install build

    git clone --depth=1 https://github.com/libsdl-org/SDL_ttf.git
    cd SDL_ttf && cmake -B build && cmake --build build -j$(nproc) && sudo cmake --install build

    git clone --depth=1 https://github.com/libsdl-org/SDL_image.git
    cd SDL_image && cmake -B build && cmake --build build -j$(nproc) && sudo cmake --install build

---

## SDL3 vs SDL2 Key Differences

  SDL2: SDL_CreateWindow(t,x,y,w,h,flags)     SDL3: SDL_CreateWindow(t,w,h,flags)
  SDL2: SDL_CreateRenderer(win,-1,flags)       SDL3: SDL_CreateRenderer(win,NULL)
  SDL2: SDL_Rect (int)                         SDL3: SDL_FRect (float) for all rendering
  SDL2: SDL_RenderCopy                         SDL3: SDL_RenderTexture
  SDL2: SDL_FreeSurface                        SDL3: SDL_DestroySurface
  SDL2: SDL_RENDERER_PRESENTVSYNC flag         SDL3: SDL_SetRenderVSync(ren, 1)
  SDL2: SDL_RenderSetClipRect                  SDL3: SDL_SetRenderClipRect
  SDL2: TTF_SizeUTF8(f,t,&w,&h)               SDL3: TTF_GetStringSize(f,t,0,&w,&h)
  SDL2: TTF_RenderUTF8_Blended(f,t,col)       SDL3: TTF_RenderText_Blended(f,t,0,col)
  SDL2: TTF_OpenFont(path, int_size)           SDL3: TTF_OpenFont(path, float_size)
  SDL2: IMG_Init(flags) required               SDL3: No IMG_Init needed
  SDL2: ev.key.keysym.sym                      SDL3: ev.key.key
  SDL2: SDL_bool return (0=fail)               SDL3: bool return (false=fail)
