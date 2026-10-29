SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "${SCRIPT_DIR}/thirdparty/miniconda3/bin/activate" rl-motion || return 1
if [[ -x "$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-c++" ]]; then
    export CXX="$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-c++"
fi
export CPATH="$CONDA_PREFIX/include${CPATH:+:$CPATH}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$CONDA_PREFIX/lib"
export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
