#!/usr/bin/env bash
# View saved metrics independently from training.
set -eo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STATE_DIR="$SCRIPT_DIR/legged_gym/logs/.tensorboard_bg"
if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
    cat <<'EOF'
Usage: ./tensorboard.sh [run_directory] [--port PORT]
Defaults to the last background run and its last TensorBoard port.
Runs in the foreground; Ctrl+C stops only this TensorBoard server.
EOF
    exit 0
fi
RUN_DIR=
PORT=6006
[[ ! -f "$STATE_DIR/port" ]] || read -r PORT < "$STATE_DIR/port"
if [[ $# -gt 0 && "$1" != --* ]]; then
    RUN_DIR=$1
    shift
elif [[ -f "$STATE_DIR/run_dir" ]]; then
    read -r RUN_DIR < "$STATE_DIR/run_dir"
fi
while (($#)); do
    case "$1" in
        --port)
            [[ $# -ge 2 ]] || { echo 'Missing port value' >&2; exit 1; }
            PORT=$2
            shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done
[[ "$PORT" =~ ^[1-9][0-9]{0,4}$ ]] && ((PORT <= 65535)) || { echo 'Invalid port' >&2; exit 1; }
[[ -n "$RUN_DIR" && -d "$RUN_DIR/tensorboard" ]] || { echo 'Run has no tensorboard directory; supply a run directory.' >&2; exit 1; }
source "$SCRIPT_DIR/source_dev_setup.sh"
echo "TensorBoard: http://localhost:$PORT/#scalars"
echo "Metrics: $RUN_DIR/tensorboard"
exec env PYTHONPATH="$SCRIPT_DIR/thirdparty/tensorboard_compat${PYTHONPATH:+:$PYTHONPATH}" \
    tensorboard --logdir "$RUN_DIR/tensorboard" --host 127.0.0.1 --port "$PORT"
