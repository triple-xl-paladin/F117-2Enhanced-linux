#!/bin/sh
# Build f117-enhanced on Linux: checks the dependencies, configures and builds (CMake + Ninja).
# See BUILDING-linux.md for the manual commands and the test-suite notes.
#
#   ./build.sh           configure (Release, the launcher off) and build
#   ./build.sh --test   build, then run ctest
#   BUILD_DIR=...       build into another directory

set -e

cd "$(dirname "$0")"

BUILD_DIR="${BUILD_DIR:-f117port/build}"
WITH_TEST=0
for arg in "$@"; do
    case "$arg" in
        --test) WITH_TEST=1 ;;
        -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
        *) echo "build.sh: unknown option: $arg (see --help)" >&2; exit 1 ;;
    esac
done

die() {
    echo "build.sh: $1" >&2
    exit 1
}

# CMake >= 3.24.
command -v cmake >/dev/null 2>&1 || die "cmake is not installed (Debian/Ubuntu: apt install cmake; Fedora: dnf install cmake; Arch: pacman -S cmake; openSUSE: zypper install cmake)."
CMAKE_VERSION=$(cmake --version | head -n 1 | awk 'NR==1 {print $3}')
CMAKE_OK=$(awk -v v="$CMAKE_VERSION" 'BEGIN { split(v, p, "."); print (p[1] * 10000 + p[2] * 100 + (p[3] + 0) >= 32400) ? 1 : 0 }')
[ "$CMAKE_OK" = 1 ] || die "CMake 3.24 or newer is needed, found $CMAKE_VERSION."

command -v ninja >/dev/null 2>&1 || die "ninja is not installed (Debian/Ubuntu: apt install ninja-build; Fedora: dnf install ninja-build; Arch: pacman -S ninja; openSUSE: zypper install ninja)."

# A C11 compiler. A C++ compiler is needed only for the launcher, which is off by default here.
command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1 || command -v clang >/dev/null 2>&1 || \
    die "no C compiler found (Debian/Ubuntu: apt install gcc; Fedora: dnf install gcc; Arch: pacman -S gcc; openSUSE: zypper install gcc)."

# The SDL3 development package; the CMake configure below is the final gate.
if command -v pkg-config >/dev/null 2>&1; then
    if ! pkg-config --exists sdl3; then
        die "the SDL3 development package is not found (pkg-config has no sdl3). Install it:
  Debian/Ubuntu:  apt install libsdl3-dev
  Fedora:         dnf install SDL3-devel
  Arch:           pacman -S sdl3
  openSUSE:       zypper install SDL3-devel
and re-run."
    fi
else
    echo "build.sh: pkg-config not found; the SDL3 check happens in the CMake configure."
fi

if [ "$WITH_TEST" = 1 ] && ! command -v python3 >/dev/null 2>&1; then
    echo "build.sh: warning: python3 not found; the gen_*_current tests are not registered (Debian/Ubuntu: apt install python3)." >&2
fi

cmake -S f117port -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release -DF117_LAUNCHER=OFF
cmake --build "$BUILD_DIR"

if [ "$WITH_TEST" = 1 ]; then
    ctest --test-dir "$BUILD_DIR" --output-on-failure
fi
