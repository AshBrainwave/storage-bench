# storage-bench

# NIXL and NIXLBench Complete Build Script

This script automates the complete build process for NIXL and NIXLBench, including all dependencies.

## Quick Start

```bash
# Full build with defaults
./utils/build_nixl_complete.sh

# After build, source the environment
source utils/nixl_env.sh

# Test nixlbench
nixlbench --help
```

## What It Does

The script performs the following steps:

1. **Checks Prerequisites** - Verifies required tools and CUDA installation
2. **Installs Dependencies** - Installs system packages (Ubuntu/Debian)
3. **Sets Up Python Environment** - Creates virtual environment with uv and installs Python packages
4. **Builds etcd-cpp-api** - Required for ETCD runtime support
5. **Builds UCX** - Communication library (or uses system UCX if available)
6. **Clones NIXL** - Downloads NIXL repository from GitHub
7. **Builds NIXL** - Compiles the core NIXL library
8. **Builds NIXLBench** - Compiles the benchmark tool
9. **Sets Up Environment** - Creates environment setup script
10. **Verifies Installation** - Checks that everything is built correctly

## Usage Options

```bash
# Show help
./utils/build_nixl_complete.sh --help

# Clean rebuild
./utils/build_nixl_complete.sh --clean

# Skip dependency installation (if already installed)
./utils/build_nixl_complete.sh --skip-deps

# Skip building etcd-cpp-api (if already installed)
./utils/build_nixl_complete.sh --skip-etcd

# Use system UCX instead of building from source
./utils/build_nixl_complete.sh --skip-ucx

# Custom installation prefix
INSTALL_PREFIX=/opt/nixl ./utils/build_nixl_complete.sh

# Custom CUDA path
CUDA_PATH=/usr/local/cuda-12.8 ./utils/build_nixl_complete.sh

# Debug build
./utils/build_nixl_complete.sh --build-type debug
```

## Environment Variables

- `BUILD_DIR` - Build directory (default: `$PROJECT_ROOT/build`)
- `INSTALL_PREFIX` - Installation prefix (default: `$PROJECT_ROOT/install`)
- `CUDA_PATH` - CUDA installation path (default: `/usr/local/cuda`)
- `PYTHON_VERSION` - Python version (default: `3.12`)
- `BUILD_TYPE` - Build type: `debug`, `release`, `debugoptimized` (default: `release`)

## After Build

After the build completes, you'll have:

1. **Environment Script**: `utils/nixl_env.sh` - Source this to set up your environment
2. **Installation**: Libraries and binaries in `install/` directory
3. **Ready to Test**: `nixlbench` is ready to use

### Using the Environment

```bash
# Source the environment file
source utils/nixl_env.sh

# Or manually set paths
export PATH=$PROJECT_ROOT/install/nixlbench/bin:$PROJECT_ROOT/install/nixl/bin:$PATH
export LD_LIBRARY_PATH=$PROJECT_ROOT/install/nixlbench/lib:$PROJECT_ROOT/install/nixl/lib/$(uname -m)-linux-gnu:$LD_LIBRARY_PATH
```

### Testing

```bash
# Test nixlbench help
nixlbench --help

# Test with storage backend (no ETCD needed)
mkdir -p /tmp/nixlbench_test
nixlbench --backend POSIX --filepath /tmp/nixlbench_test --op_type READ --num_iter 10

# Test with UCX backend (requires ETCD)
nixlbench --backend UCX --device_list=all
```

## Troubleshooting

### CUDA Not Found

```bash
# Set CUDA_PATH explicitly
CUDA_PATH=/usr/local/cuda-12.8 ./utils/build_nixl_complete.sh
```

### Missing Dependencies

```bash
# Install dependencies manually
sudo apt-get update
sudo apt-get install -y build-essential cmake ninja-build pkg-config \
  libgflags-dev libprotobuf-dev libcpprest-dev libcurl4-openssl-dev \
  libssl-dev python3-dev python3-pip
```

### Build Failures

```bash
# Clean rebuild
./utils/build_nixl_complete.sh --clean

# Skip steps that already succeeded
./utils/build_nixl_complete.sh --skip-nixl --skip-etcd
```

### Library Not Found at Runtime

```bash
# Update library cache
sudo ldconfig

# Or set LD_LIBRARY_PATH explicitly
export LD_LIBRARY_PATH=$PROJECT_ROOT/install/nixl/lib/$(uname -m)-linux-gnu:$LD_LIBRARY_PATH
```

## Comparison with Docker Build

The script provides a native build alternative to the Docker container approach:

| Feature | Native Build (This Script) | Docker Build |
|---------|---------------------------|--------------|
| Setup Complexity | Medium | Low |
| Build Time | Faster (no container overhead) | Slower (container build) |
| Dependencies | Manual management | Automatic |
| System Integration | Direct | Isolated |
| Development | Easier debugging | Container debugging |

## Next Steps

After building:

1. **Read NIXLBench Documentation**: See `nixl/benchmark/nixlbench/README.md`
2. **Run Benchmarks**: Test different backends (UCX, POSIX, GDS, etc.)
3. **Configure ETCD**: If using UCX backend, ensure ETCD is running
4. **Performance Tuning**: Adjust system parameters for optimal performance

## Support

- NIXL Repository: https://github.com/ai-dynamo/nixl
- Issues: https://github.com/ai-dynamo/nixl/issues
- Documentation: See `nixl/benchmark/nixlbench/README.md`