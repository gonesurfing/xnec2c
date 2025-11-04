# Building xnec2c on macOS

This guide provides instructions for building xnec2c natively on macOS using Homebrew. Native builds offer significantly better performance than Docker+XQuartz due to direct use of the Quartz graphics backend.

## Why Build Natively on macOS?

**Performance Benefits:**
- **No X11 overhead**: Uses native Quartz backend instead of X11 forwarding
- **Hardware acceleration**: Direct GPU access for GTK3 rendering
- **Lower latency**: No network protocol between application and display
- **Better responsiveness**: Smoother interaction and faster redraws

**vs Docker + XQuartz:**
- Docker with XQuartz can be laggy due to X11 protocol overhead
- Native build is typically 5-10x faster for graphics operations
- Native build integrates better with macOS

## Prerequisites

### 1. Install Homebrew

If you don't have Homebrew installed:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Xcode Command Line Tools

```bash
xcode-select --install
```

## Installation

### Quick Install (Automated)

Use the provided build script:

```bash
./build-macos.sh
```

This script will:
1. Check for required dependencies
2. Install missing packages via Homebrew
3. Set up the build environment
4. Run autogen.sh, configure, and make
5. Optionally install the application

### Manual Install (Step by Step)

#### Step 1: Install Dependencies

```bash
# Install build tools
brew install autoconf automake libtool pkg-config gettext

# Install GTK3 and GLib
brew install gtk+3 glib

# Install math libraries for acceleration (optional but recommended)
brew install openblas
```

#### Step 2: Set Up Environment

Homebrew's gettext is "keg-only" (not linked by default), so you need to add it to your PATH:

```bash
export PATH="/usr/local/opt/gettext/bin:$PATH"
export PKG_CONFIG_PATH="/usr/local/opt/gettext/lib/pkgconfig:$PKG_CONFIG_PATH"
```

For Apple Silicon Macs, use:
```bash
export PATH="/opt/homebrew/opt/gettext/bin:$PATH"
export PKG_CONFIG_PATH="/opt/homebrew/opt/gettext/lib/pkgconfig:$PKG_CONFIG_PATH"
```

**Tip:** Add these to your `~/.zshrc` or `~/.bash_profile` to make them permanent.

#### Step 3: Generate Build Files

```bash
./autogen.sh
```

This will:
- Check for required autotools versions
- Generate configure script
- Set up build system

Expected output should end with:
```
The xnec2c build system is now prepared.  To build here, run:
  ./configure
  make
```

#### Step 4: Configure the Build

```bash
./configure
```

Optional configure flags:
- `--enable-optimizations` - Enable compiler optimizations (default: enabled)
- `--disable-optimizations` - Disable optimizations (useful for debugging)
- `--prefix=/custom/path` - Install to custom location (default: /usr/local)

To see all options:
```bash
./configure --help
```

#### Step 5: Build

```bash
make -j$(sysctl -n hw.ncpu)
```

The `-j` flag enables parallel compilation using all CPU cores.

#### Step 6: Test (Optional)

Test the binary before installing:
```bash
./src/xnec2c
```

If you have example files:
```bash
./src/xnec2c examples/airplane.nec
```

#### Step 7: Install (Optional)

```bash
sudo make install
```

This installs:
- Binary: `/usr/local/bin/xnec2c`
- Man page: `/usr/local/share/man/man1/xnec2c.1`
- Documentation: `/usr/local/share/doc/xnec2c/`

To install to a different location, use `--prefix` during configure.

## Running xnec2c

After installation:
```bash
xnec2c
```

Or run directly from build directory:
```bash
./src/xnec2c
```

### Command Line Options

- `-i <file>` - Open NEC2 input file at startup
- `-j <n>` - Enable multi-threading with n processors
- `-h` - Show help

Example with multi-threading:
```bash
xnec2c -j4 -i myantenna.nec
```

## Troubleshooting

### Problem: autogen.sh fails with "autopoint does not exist"

**Solution:** Ensure gettext is in your PATH:
```bash
export PATH="/usr/local/opt/gettext/bin:$PATH"
./autogen.sh
```

For Apple Silicon:
```bash
export PATH="/opt/homebrew/opt/gettext/bin:$PATH"
./autogen.sh
```

### Problem: configure fails with "pkg-config not found"

**Solution:** Install pkg-config:
```bash
brew install pkg-config
```

### Problem: configure fails with "GTK+ 3.18.0 or higher is required"

**Solution:** Install or update GTK+3:
```bash
brew install gtk+3
# or
brew upgrade gtk+3
```

### Problem: "glib-compile-resources not found"

**Solution:** Ensure glib is properly installed:
```bash
brew install glib
# Verify it's available
which glib-compile-resources
```

### Problem: Math libraries not detected at runtime

The application will work without accelerated math libraries, but performance will be slower. To check which libraries are detected:

1. Start xnec2c
2. Go to File → Math Libraries → Help

To install OpenBLAS:
```bash
brew install openblas
```

Note: The application dynamically loads math libraries, so you can install them after building and they'll be detected on next launch.

### Problem: Application crashes on startup

1. Check library dependencies:
```bash
otool -L ./src/xnec2c
```

2. Try running with verbose output:
```bash
./src/xnec2c --verbose
```

3. Check for GTK warnings:
```bash
GTK_DEBUG=all ./src/xnec2c
```

### Problem: Building on Apple Silicon (M1/M2/M3)

Apple Silicon Macs use `/opt/homebrew` instead of `/usr/local`. Update your PATH:

```bash
export PATH="/opt/homebrew/bin:/opt/homebrew/opt/gettext/bin:$PATH"
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/opt/homebrew/opt/gettext/lib/pkgconfig:$PKG_CONFIG_PATH"
```

Then rebuild:
```bash
make clean
./autogen.sh
./configure
make -j$(sysctl -n hw.ncpu)
```

## Uninstalling

If installed via `make install`:
```bash
sudo make uninstall
```

If you only built but didn't install:
```bash
make clean
```

To completely remove build artifacts:
```bash
make distclean
```

## Performance Tuning

### Multi-threading

Enable multi-threaded calculations for frequency sweeps:
```bash
xnec2c -j4  # Use 4 cores
```

Recommended value: Number of CPU cores (or less if running other tasks).

### Math Library Acceleration

For best calculation performance, ensure OpenBLAS is installed:
```bash
brew install openblas
```

Check detection: File → Math Libraries → Help in the application.

### Compiler Optimizations

By default, xnec2c builds with `-O3` optimizations. For maximum performance on your specific CPU:

```bash
./configure CFLAGS="-O3 -march=native -mtune=native"
make clean
make -j$(sysctl -n hw.ncpu)
```

**Note:** `-march=native` builds for your specific CPU, so the binary may not work on other Macs.

## Development Builds

For debugging or development:

```bash
./configure --disable-optimizations CFLAGS="-g -O0"
make
```

This enables debug symbols and disables optimization for easier debugging.

## Updating xnec2c

To update to a newer version:

```bash
# Get latest code
git pull

# Clean previous build
make distclean

# Rebuild
./autogen.sh
./configure
make -j$(sysctl -n hw.ncpu)
sudo make install
```

## Comparison with Docker

| Feature | Native macOS | Docker + XQuartz |
|---------|--------------|------------------|
| Graphics Performance | Excellent (native Quartz) | Poor (X11 forwarding) |
| Setup Complexity | Medium | Low |
| Integration | Native macOS | Requires XQuartz |
| Portability | macOS only | Any platform |
| Updates | Rebuild from source | Pull new image |

**Recommendation:**
- **Native build** for regular use on macOS (best performance)
- **Docker** for testing, quick demos, or if you need consistency across platforms

## Additional Resources

- [xnec2c Website](https://www.xnec2c.org/)
- [Project Repository](https://github.com/KJ7LNW/xnec2c)
- [NEC2 Documentation](https://www.nec2.org/)

## Getting Help

If you encounter issues:

1. Check this troubleshooting guide
2. Review the build output for specific errors
3. Check the [GitHub Issues](https://github.com/KJ7LNW/xnec2c/issues)
4. Include build output and system info when reporting issues:
   ```bash
   sw_vers
   brew --version
   ./configure --version
   ```
