#!/bin/bash
# NIXL and NIXLBench Environment Setup
# Source this file: source utils/nixl_env.sh

export PATH="/home/ubuntu/ashutosh/storage-benchmarks/install/nixlbench/bin:/home/ubuntu/ashutosh/storage-benchmarks/install/nixl/bin:$PATH"
export LD_LIBRARY_PATH="/home/ubuntu/ashutosh/storage-benchmarks/install/nixlbench/lib:/home/ubuntu/ashutosh/storage-benchmarks/install/nixl/lib/aarch64-linux-gnu:/home/ubuntu/ashutosh/storage-benchmarks/install/nixl/lib/aarch64-linux-gnu/plugins:$LD_LIBRARY_PATH"

# CUDA paths
export CUDA_PATH="/usr/local/cuda"
export PATH="$CUDA_PATH/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_PATH/lib64:$LD_LIBRARY_PATH"

# Python virtual environment
source "/home/ubuntu/ashutosh/storage-benchmarks/build/.venv/bin/activate"

echo "NIXL environment loaded"
echo "  NIXL: /home/ubuntu/ashutosh/storage-benchmarks/install/nixl"
echo "  NIXLBench: /home/ubuntu/ashutosh/storage-benchmarks/install/nixlbench"
echo "  Python: $(which python)"
