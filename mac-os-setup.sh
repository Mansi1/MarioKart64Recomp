#!/bin/bash

# 1. Xcode & Metal Compiler Check
echo "--- Verifying Xcode & Metal Environment ---"
XCODE_PATH=$(xcode-select -p)
if [[ "$XCODE_PATH" == "/Library/Developer/CommandLineTools" ]]; then
    echo "❌ ERROR: Active developer directory is set to 'Command Line Tools'."
    echo "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

if ! xcrun -f metal &>/dev/null; then
    echo "❌ ERROR: 'metal' compiler not found via xcrun."
    exit 1
fi
echo "✅ Xcode and Metal compiler detected."

# 2. Install System Dependencies
echo "--- Installing Homebrew Dependencies ---"
brew install cmake ninja ccache sdl2 freetype lunasvg pkg-config llvm lld

# 3. Setup PATHs
export PATH="/opt/homebrew/opt/ccache/libexec:/opt/homebrew/opt/llvm/bin:/opt/homebrew/bin:$PATH"

# 4. Initialize Main Project Submodules
echo "--- Initializing Project Submodules ---"
git submodule update --init --recursive

# 5. Build the Recompiler Tools (Stored in lib/)
echo "--- Building N64Recomp Tools ---"
mkdir -p lib
if [ ! -d "lib/N64RecompSource" ]; then
    git clone https://github.com/Mr-Wiseguy/N64Recomp.git lib/N64RecompSource
fi

cd lib/N64RecompSource
git submodule update --init --recursive
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build --target N64Recomp --target RSPRecomp

# Move tools up to the main project root
cp build/N64Recomp ../../
cp build/RSPRecomp ../../
cd ../../

# 6. Generate Recompiled C++ Source
echo "--- Generating Game Source Files ---"
# Check for ROM (Looking for common names)
ROM_FILE=""
if [ -f "mk64.us.z64" ]; then ROM_FILE="mk64.us.z64"; fi
if [ -f "baserom.us.z64" ]; then ROM_FILE="baserom.us.z64"; fi

if [ -z "$ROM_FILE" ]; then
    echo "❌ ERROR: Big Endian ROM (.z64) not found in the root folder."
    exit 1
fi

./N64Recomp us.toml
./RSPRecomp aspMain.us.toml

# 7. Final Project Configuration
echo "--- Configuring MarioKart64Recomp ---"
rm -rf build
mkdir build && cd build

cmake .. -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="/opt/homebrew" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DCMAKE_C_COMPILER="/opt/homebrew/opt/llvm/bin/clang" \
  -DCMAKE_CXX_COMPILER="/opt/homebrew/opt/llvm/bin/clang++" \
  -DPATCHES_C_COMPILER="/opt/homebrew/opt/llvm/bin/clang" \
  -DPATCHES_LD="/opt/homebrew/bin/ld.lld" \
  -DCMAKE_AR="/opt/homebrew/opt/llvm/bin/llvm-ar" \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_CXX_FLAGS="-Wno-error=#warnings"

echo "--- Setup Complete ---"
echo "✅ Build files (build.ninja) have been created in the 'build' folder."
echo "👉 Run the following command to start the build:"
echo "cd build && ninja MarioKart64Recompiled"