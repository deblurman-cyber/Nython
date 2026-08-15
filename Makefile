# ══════════════════════════════════════════════════════════════════════
# Nython — Makefile
#
# Targets:
#   make            Build with IDE support (default)
#   make ide        Same as above (explicit)
#   make cli        Build CLI-only (no IDE launcher, opens REPL)
#   make clean      Remove all build artifacts
#   make help       Show this message
#
# Variables:
#   NYTHON_WITH_IDE=1   (default) Binary opens NythonIDE on no arguments
#   NYTHON_WITH_IDE=0   Binary opens terminal REPL on no arguments
#
# SDL3 is always required. Install: libsdl3-dev libsdl3-ttf-dev libsdl3-image-dev
#
# Example:
#   make                       # Build IDE binary
#   make cli                   # Build CLI-only binary
# ══════════════════════════════════════════════════════════════════════

CXX     = g++
CXXSTD  = -std=c++20
CXXWARN = -Wall -Wextra -Wpedantic -Weffc++
CXXOPT  = -O2
INCLUDE = -I include

SRCS = $(wildcard src/*.cpp) $(wildcard src/builtins/*.cpp)

ifeq ($(OS),Windows_NT)
  LDFLAGS = -lws2_32
  EXE     = .exe
else
  LDFLAGS = -lpthread
  EXE     =
endif

# ── SDL3 GUI backend (always enabled) ─────────────────────────────
# Detection order: sdl3-config, pkg-config, then sane defaults.
#
# NYTHON_SDL_STUB controls whether the real SDL3/SDL3_ttf/SDL3_image is
# linked or the headless stub under thirdparty/sdl3-stub/ is used instead:
#   NYTHON_SDL_STUB=0    force the real SDL3 path (fail if not found)
#   NYTHON_SDL_STUB=1    force the stub, even if a real SDL3 is installed
#   (unset)              auto-detect: use the stub only if no real SDL3
#                         can be found via sdl3-config/pkg-config or the
#                         standard header search paths.
NYTHON_SDL_STUB ?= auto

STUB_DIR     = thirdparty/sdl3-stub
STUB_INCLUDE = -I$(STUB_DIR)/include
STUB_SRC     = $(STUB_DIR)/src/sdl3_stub.cpp

SDL3_CFLAGS_REAL  := $(shell sdl3-config --cflags 2>/dev/null || pkg-config --cflags sdl3 2>/dev/null)
SDL3_LDFLAGS_REAL := $(shell sdl3-config --libs   2>/dev/null || pkg-config --libs   sdl3 2>/dev/null)
HAVE_SDL3_CONFIG  := $(shell (sdl3-config --version >/dev/null 2>&1 || pkg-config --exists sdl3 2>/dev/null) && echo yes)
HAVE_SDL3_HEADER  := $(shell test -f /usr/local/include/SDL3/SDL.h -o -f /usr/include/SDL3/SDL.h && echo yes)

ifeq ($(NYTHON_SDL_STUB),1)
  USE_SDL_STUB := yes
else ifeq ($(NYTHON_SDL_STUB),0)
  USE_SDL_STUB := no
else
  ifeq ($(HAVE_SDL3_CONFIG)$(HAVE_SDL3_HEADER),)
    USE_SDL_STUB := yes
  else
    USE_SDL_STUB := no
  endif
endif

ifeq ($(USE_SDL_STUB),yes)
  # Headless SDL3/SDL3_ttf/SDL3_image stand-in — see thirdparty/sdl3-stub/.
  # No real SDL3 is linked; the stub's own .cpp is added to the object list
  # below and provides every symbol gui.cpp needs as a headless no-op.
  SDL3_CFLAGS  := $(STUB_INCLUDE)
  SDL3_LDFLAGS :=
else
  SDL3_CFLAGS  := $(SDL3_CFLAGS_REAL)
  SDL3_LDFLAGS := $(SDL3_LDFLAGS_REAL)
  # If neither tool found anything, fall back to standard search paths
  ifeq ($(strip $(SDL3_CFLAGS)),)
    SDL3_CFLAGS  = -I/usr/local/include
  endif
  ifeq ($(strip $(SDL3_LDFLAGS)),)
    SDL3_LDFLAGS = -L/usr/local/lib -lSDL3
  endif
  SDL3_LDFLAGS += -lSDL3_ttf -lSDL3_image
endif

# ── IDE build (default) ────────────────────────────────────────────
IDE_BUILDDIR   = build/ide
IDE_OBJS       = $(patsubst src/%.cpp,$(IDE_BUILDDIR)/%.o,$(filter src/%.cpp,$(SRCS))) \
                 $(patsubst src/builtins/%.cpp,$(IDE_BUILDDIR)/builtins/%.o,$(filter src/builtins/%.cpp,$(SRCS)))
IDE_TARGET     = build/nython$(EXE)
IDE_CXXFLAGS   = $(CXXSTD) $(CXXOPT) $(CXXWARN) $(INCLUDE) -DNYTHON_WITH_IDE=1 $(SDL3_CFLAGS)

# ── CLI build ──────────────────────────────────────────────────────
CLI_BUILDDIR   = build/cli
CLI_OBJS       = $(patsubst src/%.cpp,$(CLI_BUILDDIR)/%.o,$(filter src/%.cpp,$(SRCS))) \
                 $(patsubst src/builtins/%.cpp,$(CLI_BUILDDIR)/builtins/%.o,$(filter src/builtins/%.cpp,$(SRCS)))
CLI_TARGET     = build/nython-cli$(EXE)
CLI_CXXFLAGS   = $(CXXSTD) $(CXXOPT) $(CXXWARN) $(INCLUDE) -DNYTHON_WITH_IDE=0 $(SDL3_CFLAGS)

ifeq ($(USE_SDL_STUB),yes)
  IDE_OBJS += $(IDE_BUILDDIR)/sdl3_stub.o
  CLI_OBJS += $(CLI_BUILDDIR)/sdl3_stub.o
endif

.PHONY: all ide cli clean help

# ── Default: IDE build ──────────────────────────────────────────────
all: ide

ide: $(IDE_TARGET)
	@echo ""
	@echo "  ✓  $(IDE_TARGET)  [IDE build]"
	@echo "     No-arg: launches NythonIDE GUI"
	@echo "     --cli:  forces terminal REPL"
	@echo "     SDL3:   $(if $(filter yes,$(USE_SDL_STUB)),headless stub (thirdparty/sdl3-stub),real SDL3)"
	@echo ""

cli: $(CLI_TARGET)
	@echo ""
	@echo "  ✓  $(CLI_TARGET)  [CLI build]"
	@echo "     No-arg: terminal REPL"
	@echo "     SDL3:   $(if $(filter yes,$(USE_SDL_STUB)),headless stub (thirdparty/sdl3-stub),real SDL3)"
	@echo ""

# ── Link ───────────────────────────────────────────────────────────
$(IDE_TARGET): $(IDE_OBJS) | build
	$(CXX) $(IDE_CXXFLAGS) $^ -o $@ $(LDFLAGS) $(SDL3_LDFLAGS)

$(CLI_TARGET): $(CLI_OBJS) | build
	$(CXX) $(CLI_CXXFLAGS) $^ -o $@ $(LDFLAGS) $(SDL3_LDFLAGS)

# ── Compile IDE objects ────────────────────────────────────────────
$(IDE_BUILDDIR)/%.o: src/%.cpp | $(IDE_BUILDDIR)
	$(CXX) $(IDE_CXXFLAGS) -c $< -o $@

$(IDE_BUILDDIR)/builtins/%.o: src/builtins/%.cpp | $(IDE_BUILDDIR)/builtins
	$(CXX) $(IDE_CXXFLAGS) -c $< -o $@

# ── Compile CLI objects ────────────────────────────────────────────
$(CLI_BUILDDIR)/%.o: src/%.cpp | $(CLI_BUILDDIR)
	$(CXX) $(CLI_CXXFLAGS) -c $< -o $@

$(CLI_BUILDDIR)/builtins/%.o: src/builtins/%.cpp | $(CLI_BUILDDIR)/builtins
	$(CXX) $(CLI_CXXFLAGS) -c $< -o $@

# ── Compile SDL3 stub (only when USE_SDL_STUB=yes) ────────────────
$(IDE_BUILDDIR)/sdl3_stub.o: $(STUB_SRC) | $(IDE_BUILDDIR)
	$(CXX) $(IDE_CXXFLAGS) -c $< -o $@

$(CLI_BUILDDIR)/sdl3_stub.o: $(STUB_SRC) | $(CLI_BUILDDIR)
	$(CXX) $(CLI_CXXFLAGS) -c $< -o $@

# ── Directories ────────────────────────────────────────────────────
build:
	mkdir -p build
$(IDE_BUILDDIR):
	mkdir -p $(IDE_BUILDDIR)
$(IDE_BUILDDIR)/builtins:
	mkdir -p $(IDE_BUILDDIR)/builtins
$(CLI_BUILDDIR):
	mkdir -p $(CLI_BUILDDIR)
$(CLI_BUILDDIR)/builtins:
	mkdir -p $(CLI_BUILDDIR)/builtins

# ── Clean ──────────────────────────────────────────────────────────
clean:
	rm -rf build

# ── Help ───────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  Nython Build System"
	@echo ""
	@echo "  make          Build IDE version → build/nython"
	@echo "  make ide      Same as above"
	@echo "  make cli      Build CLI version → build/nython-cli"
	@echo "  make clean    Remove all build artifacts"
	@echo ""
	@echo "  SDL3 is always required:"
	@echo "    apt install libsdl3-dev libsdl3-ttf-dev libsdl3-image-dev"
	@echo ""
	@echo "  Produced binaries:"
	@echo "    build/nython      IDE build (opens NythonIDE by default)"
	@echo "    build/nython-cli  CLI build (opens REPL by default)"
	@echo ""
