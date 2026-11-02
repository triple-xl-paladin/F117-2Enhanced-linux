# The Linux build, a thin wrapper over CMake + Ninja (see BUILDING-linux.md). The Windows build is
# unchanged: the same CMake project, the same commands (README.md "Building").
#
#   make          configure (Release, the launcher off) and build f117-enhanced
#   make test     build, then run ctest in the build directory
#   make clean    remove the build directory
#
#   BUILD_DIR=...   another build directory (default f117port/build)
#   TYPE=...       another CMake build type (default Release)

BUILD_DIR ?= f117port/build
TYPE      ?= Release
CMAKE     ?= cmake

.PHONY: all configure build test clean

all: build

configure:
	$(CMAKE) -S f117port -B $(BUILD_DIR) -G Ninja -DCMAKE_BUILD_TYPE=$(TYPE) -DF117_LAUNCHER=OFF

build: configure
	$(CMAKE) --build $(BUILD_DIR)

test: build
	ctest --test-dir $(BUILD_DIR) --output-on-failure

clean:
	rm -rf $(BUILD_DIR)
