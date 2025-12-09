#!/bin/bash
#
# Complete NIXL and NIXLBench Build Script
# Based on the official build guide
#
# This script clones, builds, and installs NIXL and NIXLBench with all dependencies
# including etcd-cpp-api, UCX, and other required components.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-$PROJECT_ROOT/install}"
NIXL_REPO="${NIXL_REPO:-https://github.com/ai-dynamo/nixl.git}"
NIXL_BRANCH="${NIXL_BRANCH:-main}"
CUDA_PATH="${CUDA_PATH:-/usr/local/cuda}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
BUILD_TYPE="${BUILD_TYPE:-release}"

# Flags
SKIP_DEPENDENCIES=false
SKIP_ETCD=false
SKIP_UCX=false
SKIP_NIXL=false
SKIP_NIXLBENCH=false
CLEAN_BUILD=false
USE_DOCKER=false

# Print functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for cmake (including cmake3)
check_cmake() {
    if command_exists cmake; then
        echo "cmake"
    elif command_exists cmake3; then
        echo "cmake3"
    else
        echo ""
    fi
}

# Check prerequisites
check_prerequisites() {
    print_section "Checking Prerequisites"
    
    local missing_tools=()
    local required_tools=("git" "make" "pkg-config" "python3")
    
    # Check for cmake (including cmake3)
    local cmake_cmd=$(check_cmake)
    if [ -n "$cmake_cmd" ]; then
        print_success "cmake found ($cmake_cmd)"
        # Create alias if cmake3 is used
        if [ "$cmake_cmd" = "cmake3" ] && ! command_exists cmake; then
            alias cmake=cmake3
            print_info "Using cmake3 as cmake"
        fi
    else
        print_error "cmake not found (checked for cmake and cmake3)"
        missing_tools+=("cmake")
    fi
    
    for tool in "${required_tools[@]}"; do
        if command_exists "$tool"; then
            print_success "$tool found"
        else
            print_error "$tool not found"
            missing_tools+=("$tool")
        fi
    done
    
    # Check for CUDA
    if [ -d "$CUDA_PATH" ]; then
        print_success "CUDA found at $CUDA_PATH"
    else
        print_warning "CUDA not found at $CUDA_PATH"
        print_info "Set CUDA_PATH environment variable if CUDA is installed elsewhere"
    fi
    
    # Check for nvcc
    if command_exists nvcc; then
        print_success "nvcc found: $(nvcc --version | head -n 1)"
    elif [ -f "$CUDA_PATH/bin/nvcc" ]; then
        print_success "nvcc found at $CUDA_PATH/bin/nvcc"
        export PATH="$CUDA_PATH/bin:$PATH"
        print_info "Added $CUDA_PATH/bin to PATH"
    else
        # Try to find nvcc in common locations
        local nvcc_path=$(find /usr/local -name nvcc 2>/dev/null | head -n 1)
        if [ -n "$nvcc_path" ]; then
            local cuda_dir=$(dirname $(dirname "$nvcc_path"))
            print_success "nvcc found at $nvcc_path"
            export CUDA_PATH="$cuda_dir"
            export PATH="$cuda_dir/bin:$PATH"
            print_info "Set CUDA_PATH to $cuda_dir and added to PATH"
        else
            print_warning "nvcc not found. CUDA toolkit may not be installed."
        fi
    fi
    
    # Check for GPU
    if command_exists nvidia-smi; then
        print_success "NVIDIA GPU detected:"
        nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1 | sed 's/^/  /'
    else
        print_warning "nvidia-smi not found. GPU may not be available."
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo
        print_info "To install missing dependencies, run:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install -y build-essential cmake git pkg-config python3"
        echo
        print_info "Or install all build dependencies:"
        echo "  sudo apt-get install -y build-essential cmake ninja-build pkg-config \\"
        echo "    autotools-dev automake libtool libz-dev flex libgtest-dev \\"
        echo "    hwloc libhwloc-dev libgflags-dev libgrpc-dev libgrpc++-dev \\"
        echo "    libprotobuf-dev libaio-dev liburing-dev protobuf-compiler-grpc \\"
        echo "    libcpprest-dev etcd-server etcd-client pybind11-dev libclang-dev \\"
        echo "    libcurl4-openssl-dev libssl-dev uuid-dev zlib1g-dev python3-dev \\"
        echo "    python3-pip autoconf libnuma-dev librdmacm-dev ibverbs-providers \\"
        echo "    libibverbs-dev rdma-core ibverbs-utils libibumad-dev libucx-dev"
        exit 1
    fi
}

# Install system dependencies
install_dependencies() {
    if [ "$SKIP_DEPENDENCIES" = true ]; then
        print_info "Skipping dependency installation"
        return
    fi
    
    print_section "Installing System Dependencies"
    
    print_info "Updating package list..."
    # Try to update, but continue even if some repositories fail
    if ! sudo apt-get update -qq 2>&1 | grep -v "changed its 'Codename'"; then
        print_warning "Some repositories had issues, but continuing..."
    fi
    
    # Fix repository issues if possible
    print_info "Attempting to fix repository issues..."
    sudo apt-get update --allow-releaseinfo-change -qq 2>/dev/null || true
    
    print_info "Installing build dependencies..."
    # Install packages, but don't fail if some are unavailable
    sudo apt-get install -y \
        build-essential \
        cmake \
        ninja-build \
        pkg-config \
        autotools-dev \
        automake \
        libtool \
        libz-dev \
        flex \
        libgtest-dev \
        hwloc \
        libhwloc-dev \
        libgflags-dev \
        libgrpc-dev \
        libgrpc++-dev \
        libprotobuf-dev \
        libaio-dev \
        liburing-dev \
        protobuf-compiler-grpc \
        libcpprest-dev \
        etcd-server \
        etcd-client \
        pybind11-dev \
        libclang-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        uuid-dev \
        zlib1g-dev \
        python3-dev \
        python3-pip \
        autoconf \
        libnuma-dev \
        librdmacm-dev \
        ibverbs-providers \
        libibverbs-dev \
        rdma-core \
        ibverbs-utils \
        libibumad-dev \
        libucx-dev 2>&1 | grep -v "E: Repository" || {
        print_warning "Some packages may not be available or repository issues occurred"
        print_info "Continuing with build - missing packages may be built from source"
    }
    
    print_success "Dependency installation completed"
}

# Install uv (Python package manager)
install_uv() {
    if command_exists uv; then
        print_success "uv already installed"
        return
    fi
    
    print_info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.cargo/bin:$PATH"
    print_success "uv installed"
}

# Setup Python environment
setup_python_env() {
    print_section "Setting Up Python Environment"
    
    install_uv
    
    # Create virtual environment
    if [ ! -d "$BUILD_DIR/.venv" ]; then
        print_info "Creating Python virtual environment..."
        uv venv "$BUILD_DIR/.venv" --python "$PYTHON_VERSION"
    fi
    
    source "$BUILD_DIR/.venv/bin/activate"
    
    print_info "Installing Python dependencies..."
    uv pip install meson pybind11 patchelf pyYAML click tabulate torch numpy || true
    
    print_success "Python environment ready"
}

# Build etcd-cpp-api
build_etcd_cpp_api() {
    if [ "$SKIP_ETCD" = true ]; then
        print_info "Skipping etcd-cpp-api build"
        return
    fi
    
    print_section "Building etcd-cpp-api"
    
    local etcd_dir="$BUILD_DIR/etcd-cpp-apiv3"
    local etcd_build_dir="$etcd_dir/build"
    
    # Check if already installed
    if pkg-config --exists etcd-cpp-api 2>/dev/null; then
        print_success "etcd-cpp-api already installed"
        return
    fi
    
    # Clone repository
    if [ ! -d "$etcd_dir" ]; then
        print_info "Cloning etcd-cpp-apiv3..."
        git clone --depth 1 https://github.com/etcd-cpp-apiv3/etcd-cpp-apiv3.git "$etcd_dir"
    else
        print_info "Updating etcd-cpp-apiv3..."
        cd "$etcd_dir"
        git pull || true
    fi
    
    cd "$etcd_dir"
    
    # Remove cpprestsdk dependency from CMake config if needed
    if [ -f etcd-cpp-api-config.in.cmake ]; then
        sed -i '/^find_dependency(cpprestsdk)$/d' etcd-cpp-api-config.in.cmake || true
    fi
    
    # Build
    print_info "Building etcd-cpp-api..."
    mkdir -p "$etcd_build_dir"
    cd "$etcd_build_dir"
    
    cmake .. \
        -DBUILD_ETCD_CORE_ONLY=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX/etcd-cpp-api"
    
    make -j$(nproc)
    sudo make install || make install
    
    # Update library cache
    sudo ldconfig 2>/dev/null || true
    
    print_success "etcd-cpp-api built and installed"
}

# Build UCX (if not using system UCX)
build_ucx() {
    if [ "$SKIP_UCX" = true ]; then
        print_info "Skipping UCX build (using system UCX)"
        return
    fi
    
    # Check if system UCX is available and version is >= 1.21
    if pkg-config --exists ucx 2>/dev/null; then
        local ucx_version=$(pkg-config --modversion ucx 2>/dev/null || echo "0.0.0")
        print_info "System UCX found: version $ucx_version"
        
        # Check if version is >= 1.21 (required for UCX GPU Device API)
        local major=$(echo "$ucx_version" | cut -d. -f1)
        local minor=$(echo "$ucx_version" | cut -d. -f2)
        
        if [ "$major" -gt 1 ] || ([ "$major" -eq 1 ] && [ "$minor" -ge 21 ]); then
            print_success "System UCX version $ucx_version meets requirement (>= 1.21)"
            return
        else
            print_warning "System UCX version $ucx_version is too old (requires >= 1.21)"
            print_info "Will build UCX from source"
        fi
    fi
    
    print_section "Building UCX from Source"
    
    local ucx_dir="$BUILD_DIR/ucx"
    local ucx_version="${UCX_VERSION:-v1.21.0}"  # Use UCX 1.21+ for GPU Device API support
    
    if [ ! -d "$ucx_dir" ]; then
        print_info "Cloning UCX..."
        git clone https://github.com/openucx/ucx.git "$ucx_dir"
    else
        print_info "Updating UCX..."
        cd "$ucx_dir"
        git fetch --tags
    fi
    
    cd "$ucx_dir"
    
    # Checkout specific version
    print_info "Checking out UCX $ucx_version..."
    git checkout "$ucx_version" 2>/dev/null || {
        print_warning "Tag $ucx_version not found, using latest"
        git checkout master || git checkout main
    }
    
    print_info "Configuring UCX..."
    ./autogen.sh
    ./contrib/configure-release \
        --with-cuda="$CUDA_PATH" \
        --enable-mt \
        --prefix="$INSTALL_PREFIX/ucx"
    
    print_info "Building UCX (this may take a while)..."
    make -j$(nproc)
    
    print_info "Installing UCX..."
    sudo make install || make install
    
    # Update library cache and pkg-config path
    export PKG_CONFIG_PATH="$INSTALL_PREFIX/ucx/lib/pkgconfig:$PKG_CONFIG_PATH"
    sudo ldconfig 2>/dev/null || true
    
    print_success "UCX built and installed to $INSTALL_PREFIX/ucx"
}

# Clone NIXL repository
clone_nixl() {
    print_section "Cloning NIXL Repository"
    
    local nixl_dir="$BUILD_DIR/nixl"
    
    if [ -d "$nixl_dir" ]; then
        if [ "$CLEAN_BUILD" = true ]; then
            print_info "Removing existing NIXL directory..."
            rm -rf "$nixl_dir"
        else
            print_info "NIXL directory exists, updating..."
            cd "$nixl_dir"
            git fetch origin
            git checkout "$NIXL_BRANCH" || true
            git pull || true
            return
        fi
    fi
    
    print_info "Cloning NIXL from $NIXL_REPO..."
    git clone --depth 1 -b "$NIXL_BRANCH" "$NIXL_REPO" "$nixl_dir" || \
    git clone "$NIXL_REPO" "$nixl_dir"
    
    cd "$nixl_dir"
    git checkout "$NIXL_BRANCH" || true
    
    print_success "NIXL cloned"
}

# Build NIXL
build_nixl() {
    if [ "$SKIP_NIXL" = true ]; then
        print_info "Skipping NIXL build"
        return
    fi
    
    print_section "Building NIXL"
    
    source "$BUILD_DIR/.venv/bin/activate"
    
    local nixl_dir="$BUILD_DIR/nixl"
    local nixl_build_dir="$nixl_dir/build"
    
    cd "$nixl_dir"
    
    if [ "$CLEAN_BUILD" = true ] && [ -d "$nixl_build_dir" ]; then
        print_info "Cleaning NIXL build directory..."
        rm -rf "$nixl_build_dir"
    fi
    
    # Set PKG_CONFIG_PATH to find UCX if we built it
    if [ -d "$INSTALL_PREFIX/ucx/lib/pkgconfig" ]; then
        export PKG_CONFIG_PATH="$INSTALL_PREFIX/ucx/lib/pkgconfig:$PKG_CONFIG_PATH"
    fi
    
    print_info "Configuring NIXL build..."
    # Use regular meson, not uv run meson (which builds Python package)
    # meson setup requires: source_dir build_dir
    meson setup "$nixl_dir" "$nixl_build_dir" \
        --prefix="$INSTALL_PREFIX/nixl" \
        --buildtype="$BUILD_TYPE" \
        -Dbuild_docs=false
    
    cd "$nixl_build_dir"
    
    print_info "Building NIXL..."
    ninja
    
    print_info "Installing NIXL..."
    sudo ninja install || ninja install
    
    # Update library paths
    local lib_dir="$INSTALL_PREFIX/nixl/lib/$(uname -m)-linux-gnu"
    if [ -d "$lib_dir" ]; then
        echo "$lib_dir" | sudo tee /etc/ld.so.conf.d/nixl.conf >/dev/null 2>&1 || true
        echo "$lib_dir/plugins" | sudo tee -a /etc/ld.so.conf.d/nixl.conf >/dev/null 2>&1 || true
        sudo ldconfig 2>/dev/null || true
    fi
    
    print_success "NIXL built and installed"
}

# Build NIXLBench
build_nixlbench() {
    if [ "$SKIP_NIXLBENCH" = true ]; then
        print_info "Skipping NIXLBench build"
        return
    fi
    
    print_section "Building NIXLBench"
    
    source "$BUILD_DIR/.venv/bin/activate"
    
    local nixlbench_dir="$BUILD_DIR/nixl/benchmark/nixlbench"
    local nixlbench_build_dir="$nixlbench_dir/build"
    
    if [ ! -d "$nixlbench_dir" ]; then
        print_error "NIXLBench directory not found. Did NIXL clone succeed?"
        exit 1
    fi
    
    cd "$nixlbench_dir"
    
    if [ "$CLEAN_BUILD" = true ] && [ -d "$nixlbench_build_dir" ]; then
        print_info "Cleaning NIXLBench build directory..."
        rm -rf "$nixlbench_build_dir"
    fi
    
    print_info "Configuring NIXLBench build..."
    # Use regular meson, not uv run meson
    # meson setup requires: source_dir build_dir
    meson setup "$nixlbench_dir" "$nixlbench_build_dir" \
        -Dnixl_path="$INSTALL_PREFIX/nixl" \
        -Dprefix="$INSTALL_PREFIX/nixlbench" \
        --buildtype="$BUILD_TYPE"
    
    cd "$nixlbench_build_dir"
    
    print_info "Building NIXLBench..."
    ninja
    
    print_info "Installing NIXLBench..."
    sudo ninja install || ninja install
    
    print_success "NIXLBench built and installed"
}

# Setup environment variables
setup_environment() {
    print_section "Setting Up Environment"
    
    local env_file="$PROJECT_ROOT/utils/nixl_env.sh"
    
    cat > "$env_file" <<EOF
#!/bin/bash
# NIXL and NIXLBench Environment Setup
# Source this file: source utils/nixl_env.sh

export PATH="$INSTALL_PREFIX/nixlbench/bin:$INSTALL_PREFIX/nixl/bin:\$PATH"
export LD_LIBRARY_PATH="$INSTALL_PREFIX/nixlbench/lib:$INSTALL_PREFIX/nixl/lib/$(uname -m)-linux-gnu:$INSTALL_PREFIX/nixl/lib/$(uname -m)-linux-gnu/plugins:\$LD_LIBRARY_PATH"

# CUDA paths
export CUDA_PATH="$CUDA_PATH"
export PATH="\$CUDA_PATH/bin:\$PATH"
export LD_LIBRARY_PATH="\$CUDA_PATH/lib64:\$LD_LIBRARY_PATH"

# Python virtual environment
source "$BUILD_DIR/.venv/bin/activate"

echo "NIXL environment loaded"
echo "  NIXL: $INSTALL_PREFIX/nixl"
echo "  NIXLBench: $INSTALL_PREFIX/nixlbench"
echo "  Python: \$(which python)"
EOF
    
    chmod +x "$env_file"
    
    print_success "Environment file created: $env_file"
    print_info "Source it with: source utils/nixl_env.sh"
}

# Verify installation
verify_installation() {
    print_section "Verifying Installation"
    
    source "$BUILD_DIR/.venv/bin/activate"
    export PATH="$INSTALL_PREFIX/nixlbench/bin:$INSTALL_PREFIX/nixl/bin:$PATH"
    export LD_LIBRARY_PATH="$INSTALL_PREFIX/nixlbench/lib:$INSTALL_PREFIX/nixl/lib/$(uname -m)-linux-gnu:$INSTALL_PREFIX/nixl/lib/$(uname -m)-linux-gnu/plugins:$LD_LIBRARY_PATH"
    
    # Check nixlbench
    if [ -f "$INSTALL_PREFIX/nixlbench/bin/nixlbench" ]; then
        print_success "nixlbench binary found"
        "$INSTALL_PREFIX/nixlbench/bin/nixlbench" --help >/dev/null 2>&1 && \
            print_success "nixlbench is executable" || \
            print_warning "nixlbench may have runtime dependencies"
    else
        print_error "nixlbench binary not found"
    fi
    
    # Check libraries
    if [ -f "$INSTALL_PREFIX/nixl/lib/$(uname -m)-linux-gnu/libnixl.so" ]; then
        print_success "libnixl.so found"
    else
        print_warning "libnixl.so not found (may be in different location)"
    fi
    
    print_info "Installation verification complete"
}

# Show usage
show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Build and install NIXL and NIXLBench with all dependencies.

Options:
    --skip-deps          Skip installing system dependencies
    --skip-etcd          Skip building etcd-cpp-api
    --skip-ucx           Skip building UCX (use system UCX)
    --skip-nixl          Skip building NIXL
    --skip-nixlbench     Skip building NIXLBench
    --clean              Clean build directories before building
    --build-dir DIR      Build directory (default: $BUILD_DIR)
    --install-prefix DIR Installation prefix (default: $INSTALL_PREFIX)
    --cuda-path PATH     CUDA installation path (default: $CUDA_PATH)
    --python-version VER Python version (default: $PYTHON_VERSION)
    --build-type TYPE    Build type: debug, release, debugoptimized (default: $BUILD_TYPE)
    --help               Show this help message

Environment Variables:
    BUILD_DIR            Build directory
    INSTALL_PREFIX       Installation prefix
    CUDA_PATH            CUDA installation path
    PYTHON_VERSION       Python version
    BUILD_TYPE           Build type

Examples:
    # Full build with defaults
    $0

    # Clean rebuild
    $0 --clean

    # Custom installation prefix
    INSTALL_PREFIX=/opt/nixl $0

    # Skip dependency installation (if already installed)
    $0 --skip-deps

EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-deps)
                SKIP_DEPENDENCIES=true
                shift
                ;;
            --skip-etcd)
                SKIP_ETCD=true
                shift
                ;;
            --skip-ucx)
                SKIP_UCX=true
                shift
                ;;
            --skip-nixl)
                SKIP_NIXL=true
                shift
                ;;
            --skip-nixlbench)
                SKIP_NIXLBENCH=true
                shift
                ;;
            --clean)
                CLEAN_BUILD=true
                shift
                ;;
            --build-dir)
                BUILD_DIR="$2"
                shift 2
                ;;
            --install-prefix)
                INSTALL_PREFIX="$2"
                shift 2
                ;;
            --cuda-path)
                CUDA_PATH="$2"
                shift 2
                ;;
            --python-version)
                PYTHON_VERSION="$2"
                shift 2
                ;;
            --build-type)
                BUILD_TYPE="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    print_section "NIXL and NIXLBench Complete Build Script"
    
    parse_args "$@"
    
    # Create directories
    mkdir -p "$BUILD_DIR"
    mkdir -p "$INSTALL_PREFIX"
    
    # Run build steps
    check_prerequisites
    install_dependencies
    setup_python_env
    build_etcd_cpp_api
    build_ucx
    clone_nixl
    build_nixl
    build_nixlbench
    setup_environment
    verify_installation
    
    print_section "Build Complete!"
    print_success "NIXL and NIXLBench have been built and installed"
    print_info "Installation prefix: $INSTALL_PREFIX"
    print_info ""
    print_info "To use NIXL/NIXLBench, source the environment file:"
    print_info "  source utils/nixl_env.sh"
    print_info ""
    print_info "Or manually set:"
    print_info "  export PATH=$INSTALL_PREFIX/nixlbench/bin:$INSTALL_PREFIX/nixl/bin:\$PATH"
    print_info "  export LD_LIBRARY_PATH=$INSTALL_PREFIX/nixlbench/lib:$INSTALL_PREFIX/nixl/lib/$(uname -m)-linux-gnu:\$LD_LIBRARY_PATH"
    print_info ""
    print_info "Test nixlbench:"
    print_info "  nixlbench --help"
}

# Run main
main "$@"

