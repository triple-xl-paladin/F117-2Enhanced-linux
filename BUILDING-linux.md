# Building on Linux

The port is platform-neutral C: the same CMake project builds on Windows (MSYS2/MSVC) and on Linux
(GCC or Clang), and the source needs no `#ifdef __linux__` patches (the audit is summarised at the
bottom of this file; the Windows build is unchanged, see README.md "Building").

## Prerequisites

* CMake 3.24 or newer, Ninja, a C11 compiler (GCC or Clang)
* the SDL3 development package
* Python 3 (the `gen_*_current` tests and the reference tests use it; without it the `gen_*_current`
  tests are simply not registered, with a CMake warning)

| Distribution | packages |
|---|---|
| Debian / Ubuntu | `sudo apt install cmake ninja-build gcc libsdl3-dev python3` |
| Fedora | `sudo dnf install cmake ninja-build gcc SDL3-devel python3` |
| Arch | `sudo pacman -S cmake ninja gcc sdl3 python` |
| openSUSE | `sudo zypper install cmake ninja gcc gcc-c++ SDL3-devel python3` |

## Quick start

```bash
./build.sh            # checks the dependencies, configures (Release, launcher off) and builds
make                  # the same, via the Makefile (make test / make clean also)
ctest --test-dir f117port/build
```

or by hand:

```bash
cmake -S f117port -B f117port/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DF117_LAUNCHER=OFF
cmake --build f117port/build
ctest --test-dir f117port/build
```

Presets (from the repository root; the build directories are `f117port/build-release` / `f117port/build-debug`):

```bash
cmake --preset linux-release && cmake --build --preset linux-release
cmake --preset linux-debug    && cmake --build --preset linux-debug
```

The program is `f117port/build/f117-enhanced` (or `.../build-release/f117-enhanced`).

## Running

```bash
f117port/build/f117-enhanced --game-dir Game
```

`--game-dir DIR` (default `Game`) is the folder with the original game files; the port never ships
game data. The options are in README.md "Command line" and at the top of `f117port/src/main.c`.
The errors the game reports go to `f117.log` beside the program.

## The tests

```bash
ctest --test-dir f117port/build
```

Tests fall in three tiers:

* **Portable** (always run; no game files): `chain`, `keymap`, `tick_rate`, `check_missing_files`,
  `platform`, `compose`, `enh_interp_rules`, `enh_wide_geometry`. These exercise the port itself.
* **Game files** (need `../Game`): `exe_load`, `video_selftest`, `video_screen`, `video_decoders`.
* **Reference** (replay the ORIGINAL programs under Unicorn and compare byte for byte): `frontend`,
  `shell`, `sim_vgame`, `render3d_*`, `debrief*`, `sound*`, the `r3d_hr_*` and `enh_*` Python
  drivers, plus `gen_symbols_current` / `gen_module_headers_current` (the generated headers re-run
  and must come out unchanged).

Self-skip: a test that is missing a file it needs exits with code 77, which ctest reports as "Not
Run (skipped)". Without `Game/` the suite is the short one: the portable tests, plus
`gen_*_current` (with Python 3).

The reference tier needs a developer reference environment that is **not** part of the build:

* `unicorn` (`pip install unicorn`),
* the unpacked original executables in `work/unpacked/` (from `tools/unlzexe.py`),
* the faithful `F117-2` repository checked out next to this one — the spec files it reads
  (`F117-2/port/spec/`, used by `gen_*_current`) and the Phase 2 decoders
  (`F117-2/tools/panlib.py`, `picdec.py`, used by `video_decoders` and the front-end references).

With `Game/` present but that reference environment absent, the reference tests whose gate includes
a missing `work/unpacked/…` file self-skip (77); the ones whose gate is only the `Game/` folder then
import `unicorn` (the `--chain` variants, `sim_vgame`, `render3d_golden`, `r3d_hr_*`) or the
sibling-repo decoders (`video_decoders`, `gen_*_current`) and fail on the missing import. Those
failures are the missing reference environment, not the Linux build — identical on Windows without
it. Installing the reference environment is what turns them green.

Two `exe_load` checks compare exact bytes that "come from the image" (the VGAME keypad table and the
END `:File not found` text at a fixed offset) and assume the exact reference build; a different
F-117A 2.0 build fails those two while every structural check still passes. Not a bug.

The faithful tests run with `F117_CLASSIC=1` in their environment (set automatically by CMake,
except `compose` and the `r3d_hr_*` / `enh_*` tests). A loaded machine may make `tick_rate` see a
few fewer ticks; it passes at 64–72 ticks in 1000 ms.

## The launcher (off by default on Linux)

`F117_LAUNCHER` defaults to **OFF** on non-Windows platforms (ON on Windows): the launcher is a
wxWidgets GUI and needs wxWidgets 3.2 installed. To enable it:

```bash
cmake -S f117port -B f117port/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DF117_LAUNCHER=ON
cmake --build f117port/build
```

with the wxWidgets 3.2 development package (Debian/Ubuntu: `libwxgtk3.2-dev`; Fedora:
`wxWidgets-devel`; Arch: `wxWidgets`; openSUSE: `wxWidgets-devel`) and a C++ compiler.

Its settings are kept in `$XDG_CONFIG_HOME/f117a-enhanced/settings.ini`
(`~/.config/f117a-enhanced/settings.ini` by default); on Windows the path stays
`%APPDATA%\F-117A Enhanced\settings.ini`. With the launcher built, the `launcher_args` ctest
is registered as well.

## Source portability (why there are no `#ifdef __linux__` patches)

* `f117port/src/host.c` is the only file that includes a Windows header (`<windows.h>`), behind
  `#ifdef _WIN32` (line 10); its crash handler is already branched (Win32 exception filter vs
  `signal()`/`raise`).
* All game-file I/O goes through `f117port/src/platform/dosio.c`, which opens in binary mode
  (`rb`/`w+b`/`r+b`) and normalises DOS names (backslash to `/`, any case) to host paths; the
  case-insensitive game-file lookup is `host_game_path` (`SDL_GlobDirectory` + `SDL_strcasecmp`).
  On Linux text and binary `fopen` modes are identical, so the faithful DOS text modes need no change.
* The launcher (`f117port/launcher/`) is already platform-aware: `%APPDATA%` vs
  `$XDG_CONFIG_HOME`/`~/.config` in `settings.cpp` (`#ifdef __WXMSW__`), case-tolerant file lookups
  in `game.cpp`, and its CMake keeps the RC/comctl32/DLL steps in `if(WIN32)`.
* `f117port/CMakeLists.txt` already branches the compiler flags (MSVC `/W3` vs
  `-Wall -Wextra -fno-strict-aliasing`) and keeps the RC manifest and DLL copy in `if(WIN32)`.
* The plain SDL3 3.2.x core has no image writer (no `SDL_SavePNG`); some SDL3 builds do. The build
  detects the symbol at configure time (`check_symbol_exists`) and passes `F117_SDL_HAS_SAVE_PNG`
  to the source: the crash/step snapshots (`F117_SNAPSHOT_DIR`) use `SDL_SavePNG` when the SDL3 has
  it and write BMP otherwise — the only SDL-version difference the code accommodates.
* `third_party/nuked-opl3/opl3.c` is portable C (no OS headers); it is built as-is and untouched.
