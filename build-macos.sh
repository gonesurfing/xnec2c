#!/bin/bash
#
# build-macos.sh - Automated build script for xnec2c on macOS
#
# This script automates the process of building xnec2c on macOS by:
# - Checking for required dependencies
# - Installing missing packages via Homebrew
# - Setting up the build environment
# - Running autogen.sh, configure, and make
#
# Usage:
#   ./build-macos.sh [--install] [--help]
#
# Options:
#   --install    Install after building (requires sudo)
#   --help       Show this help message

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
DO_INSTALL=0

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --install)
            DO_INSTALL=1
            shift
            ;;
        --help)
            echo "Usage: $0 [--install] [--help]"
            echo ""
            echo "Build xnec2c natively on macOS using Homebrew dependencies."
            echo ""
            echo "Options:"
            echo "  --install    Install after building (requires sudo)"
            echo "  --help       Show this help message"
            echo ""
            echo "For more information, see INSTALL.MACOS.md"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}xnec2c macOS Build Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print status messages
print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is for macOS only"
    exit 1
fi

# Detect architecture and set Homebrew path
if [[ $(uname -m) == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
    print_status "Detected Apple Silicon (ARM64)"
else
    BREW_PREFIX="/usr/local"
    print_status "Detected Intel (x86_64)"
fi

# Check if Homebrew is installed
print_status "Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    print_error "Homebrew is not installed"
    echo "Install Homebrew from https://brew.sh/ or run:"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
fi
echo "  Found: $(brew --version | head -n1)"

# List of required packages
REQUIRED_PACKAGES=(
    "autoconf"
    "automake"
    "libtool"
    "pkg-config"
    "gettext"
    "gtk+3"
    "glib"
)

OPTIONAL_PACKAGES=(
    "openblas"
)

# Check and install required packages
print_status "Checking for required packages..."
MISSING_PACKAGES=()

for package in "${REQUIRED_PACKAGES[@]}"; do
    if brew list "$package" &> /dev/null; then
        echo "  ✓ $package"
    else
        echo "  ✗ $package (missing)"
        MISSING_PACKAGES+=("$package")
    fi
done

# Check optional packages
print_status "Checking for optional packages..."
for package in "${OPTIONAL_PACKAGES[@]}"; do
    if brew list "$package" &> /dev/null; then
        echo "  ✓ $package"
    else
        echo "  - $package (not installed, recommended for performance)"
    fi
done

# Install missing packages
if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo ""
    print_warning "Missing required packages: ${MISSING_PACKAGES[*]}"
    echo ""
    read -p "Install missing packages now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Installing missing packages..."
        brew install "${MISSING_PACKAGES[@]}"
    else
        print_error "Cannot continue without required packages"
        exit 1
    fi
fi

# Set up environment for gettext (keg-only)
print_status "Setting up build environment..."
export PATH="${BREW_PREFIX}/opt/gettext/bin:${BREW_PREFIX}/bin:$PATH"
export PKG_CONFIG_PATH="${BREW_PREFIX}/lib/pkgconfig:${BREW_PREFIX}/opt/gettext/lib/pkgconfig:$PKG_CONFIG_PATH"
echo "  PATH=${PATH}"

# Check if autogen.sh exists
if [ ! -f "./autogen.sh" ]; then
    print_error "autogen.sh not found. Are you in the xnec2c source directory?"
    exit 1
fi

# Run autogen.sh
print_status "Running autogen.sh..."
if ./autogen.sh; then
    echo -e "${GREEN}  ✓ Build system prepared${NC}"
else
    print_error "autogen.sh failed"
    exit 1
fi

# Run configure
print_status "Running configure..."
if ./configure --enable-optimizations; then
    echo -e "${GREEN}  ✓ Configuration complete${NC}"
else
    print_error "configure failed"
    exit 1
fi

# Build
NCPU=$(sysctl -n hw.ncpu)
print_status "Building xnec2c (using $NCPU cores)..."
if make -j"$NCPU"; then
    echo -e "${GREEN}  ✓ Build successful${NC}"
else
    print_error "Build failed"
    exit 1
fi

# Test the binary
print_status "Testing binary..."
if [ -f "./src/xnec2c" ]; then
    echo -e "${GREEN}  ✓ Binary created: ./src/xnec2c${NC}"
else
    print_error "Binary not found after build"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Install if requested
if [ $DO_INSTALL -eq 1 ]; then
    print_status "Installing xnec2c..."
    if sudo make install; then
        echo -e "${GREEN}  ✓ Installation complete${NC}"
        echo ""
        echo "xnec2c has been installed to: /usr/local/bin/xnec2c"
        echo "Run: xnec2c"
    else
        print_error "Installation failed"
        exit 1
    fi
else
    echo "To run xnec2c without installing:"
    echo "  ./src/xnec2c"
    echo ""
    echo "To install system-wide (requires sudo):"
    echo "  sudo make install"
    echo ""
    echo "Or run this script with --install flag:"
    echo "  ./build-macos.sh --install"
fi

echo ""
echo "Optional next steps:"
echo "  - Install OpenBLAS for faster calculations: brew install openblas"
echo "  - Read INSTALL.MACOS.md for usage tips and troubleshooting"
echo "  - Run with multi-threading: ./src/xnec2c -j$NCPU"
echo ""
