#!/usr/bin/env bash
# Detached local training, TensorBoard, and a sleep inhibitor with shared lifetime.
set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_PATH="$SCRIPT_DIR/train_tensorboard_bg.sh"
STATE_DIR="$SCRIPT_DIR/legged_gym/logs/.tensorboard_bg"
mkdir -p "$STATE_DIR"

usage() {
    cat <<'EOF'
Usage: ./train_tensorboard_bg.sh [start|status|stop] [options]
  --name NAME           Run/checkpoint folder (default: suitcase_TIMESTAMP)
  --num-envs N          Parallel environments (default: 4096)
  --max-iterations N    Override training iteration limit
  --port N              TensorBoard port on localhost (default: 6006)

Training runs locally without W&B. Closing the terminal does not stop it.
Sleep/idle inhibition lasts until training exits. Forced shutdown is not blocked.
Uses systemd-inhibit, with gnome-session-inhibit as a desktop-session fallback.
EOF
}

active() {
    [[ -f "$STATE_DIR/supervisor.pid" ]] || return 1
    local pid command_line
    read -r pid < "$STATE_DIR/supervisor.pid"
    [[ "$pid" =~ ^[0-9]+$ && -r "/proc/$pid/cmdline" ]] || return 1
    command_line=$(tr '\0' ' ' < "/proc/$pid/cmdline")
    [[ "$command_line" == *"$SCRIPT_PATH __worker "* ]]
}

show_status() {
    if active; then
        echo "Running; supervisor PID: $(cat "$STATE_DIR/supervisor.pid")"
    else
        echo "Training is not running."
    fi
    if [[ -f "$STATE_DIR/run_dir" ]]; then
        local run_dir
        read -r run_dir < "$STATE_DIR/run_dir"
        echo "Run/checkpoints: $run_dir"
        echo "Training log:   $run_dir/train.log"
        echo "TensorBoard:    http://localhost:$(cat "$STATE_DIR/port")"
        [[ ! -f "$STATE_DIR/inhibitor" ]] || echo "Anti-suspend:   $(cat "$STATE_DIR/inhibitor")"
        [[ ! -f "$run_dir/exit_code" ]] || echo "Last exit code: $(cat "$run_dir/exit_code")"
    fi
}

# Runs only inside the detached sleep-inhibitor process.
if [[ "${1:-}" == __worker ]]; then
    RUN_DIR=$2
    PORT=$3
    NUM_ENVS=$4
    MAX_ITERATIONS=$5
    TRAIN_PID=
    TB_PID=
    cleanup() {
        local code=$?
        trap - EXIT TERM INT
        [[ -z "$TRAIN_PID" ]] || kill -TERM "$TRAIN_PID" 2>/dev/null || true
        [[ -z "$TB_PID" ]] || kill -TERM "$TB_PID" 2>/dev/null || true
        [[ -z "$TRAIN_PID" ]] || wait "$TRAIN_PID" 2>/dev/null || true
        [[ -z "$TB_PID" ]] || wait "$TB_PID" 2>/dev/null || true
        echo "$code" > "$RUN_DIR/exit_code"
        rm -f "$STATE_DIR/supervisor.pid"
        exit "$code"
    }
    trap cleanup EXIT
    trap 'exit 143' TERM
    trap 'exit 130' INT
    echo "$$" > "$STATE_DIR/supervisor.pid"
    source "$SCRIPT_DIR/source_dev_setup.sh"
    cd "$SCRIPT_DIR"
    export PYTHONUNBUFFERED=1
    PYTHONPATH="$SCRIPT_DIR/thirdparty/tensorboard_compat${PYTHONPATH:+:$PYTHONPATH}" \
        tensorboard --logdir "$RUN_DIR/tensorboard" --host 127.0.0.1 --port "$PORT" \
        > "$RUN_DIR/tensorboard.log" 2>&1 9>&- &
    TB_PID=$!
    echo "$TB_PID" > "$RUN_DIR/tensorboard.pid"
    local_ready=false
    for ((i=0; i<100; i++)); do
        kill -0 "$TB_PID" 2>/dev/null || break
        if (echo > "/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then
            local_ready=true
            break
        fi
        sleep 0.2
    done
    if [[ "$local_ready" != true ]]; then
        echo "TensorBoard failed to start; see $RUN_DIR/tensorboard.log" >&2
        exit 1
    fi
    TRAIN_ARGS=(--task g1_hoi --proj_name resmimic_suitcase
        --exptid "$(basename "$RUN_DIR")" --device cuda:0 --teacher_exptid None
        --num_envs "$NUM_ENVS" --wandb_entity '' --no_wandb)
    [[ -z "$MAX_ITERATIONS" ]] || TRAIN_ARGS+=(--max_iterations "$MAX_ITERATIONS")
    python "$SCRIPT_DIR/legged_gym/legged_gym/scripts/train.py" "${TRAIN_ARGS[@]}" \
        > "$RUN_DIR/train.log" 2>&1 9>&- &
    TRAIN_PID=$!
    echo "$TRAIN_PID" > "$RUN_DIR/train.pid"
    touch "$RUN_DIR/ready"
    # End TensorBoard and the inhibitor if either service exits.
    wait -n "$TRAIN_PID" "$TB_PID"
    exit $?
fi

ACTION=start
case "${1:-}" in
    start|status|stop) ACTION=$1; shift ;;
    -h|--help) usage; exit 0 ;;
esac
if [[ "$ACTION" == status ]]; then
    show_status
    exit 0
fi
if [[ "$ACTION" == stop ]]; then
    if active; then
        read -r pid < "$STATE_DIR/supervisor.pid"
        kill -TERM "$pid"
        for ((i=0; i<100; i++)); do
            if ! active; then
                echo "Training and TensorBoard stopped; sleep inhibitor released."
                exit 0
            fi
            sleep 0.2
        done
        echo "Stop requested; cleanup still running. Check status again." >&2
        exit 1
    fi
    echo "Training is not running."
    exit 0
fi

NAME="suitcase_$(date +%Y%m%d_%H%M%S)"
NUM_ENVS=4096
MAX_ITERATIONS=
PORT=6006
while (($#)); do
    case "$1" in
        --name|--num-envs|--max-iterations|--port)
            [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 1; }
            case "$1" in
                --name) NAME=$2 ;;
                --num-envs) NUM_ENVS=$2 ;;
                --max-iterations) MAX_ITERATIONS=$2 ;;
                --port) PORT=$2 ;;
            esac
            shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done
[[ "$NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || { echo "Invalid run name" >&2; exit 1; }
[[ "$NUM_ENVS" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid environment count" >&2; exit 1; }
[[ -z "$MAX_ITERATIONS" || "$MAX_ITERATIONS" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid iteration count" >&2; exit 1; }
[[ "$PORT" =~ ^[1-9][0-9]{0,4}$ ]] && ((PORT <= 65535)) || { echo "Invalid port" >&2; exit 1; }

for tool in flock nohup setsid; do
    command -v "$tool" > /dev/null || { echo "Required command missing: $tool" >&2; exit 1; }
done
exec 9> "$STATE_DIR/lock"
flock -n 9 || { echo "A background run is already active. Use status or stop." >&2; exit 1; }
source "$SCRIPT_DIR/source_dev_setup.sh"
python -c 'import tensorboard; from torch.utils.tensorboard import SummaryWriter' 9>&-
# Permissions vary by login session; try the desktop inhibitor if logind denies us.
SYSTEMD_ERROR='systemd-inhibit is not installed'
GNOME_ERROR='gnome-session-inhibit is not installed'
if command -v systemd-inhibit > /dev/null && \
    SYSTEMD_ERROR=$(systemd-inhibit --what=sleep:idle --who=ResMimic \
        --why='Training preflight' --mode=block /bin/true 9>&- 2>&1); then
    INHIBITOR=(systemd-inhibit --what=sleep:idle --who=ResMimic
        --why="ResMimic training: $NAME" --mode=block)
    INHIBITOR_NAME=systemd-inhibit
elif command -v gnome-session-inhibit > /dev/null && \
    GNOME_ERROR=$(gnome-session-inhibit --app-id ResMimic --reason 'Training preflight' \
        --inhibit suspend:idle /bin/true 9>&- 2>&1); then
    echo "systemd-inhibit unavailable; using GNOME session anti-suspend."
    INHIBITOR=(gnome-session-inhibit --app-id ResMimic
        --reason "ResMimic training: $NAME" --inhibit suspend:idle)
    INHIBITOR_NAME=gnome-session-inhibit
else
    echo "Cannot enable anti-suspend; training was not started." >&2
    printf 'systemd: %s\nGNOME: %s\n' "$SYSTEMD_ERROR" "$GNOME_ERROR" >&2
    echo "Run from a terminal in your logged-in desktop session and retry." >&2
    exit 1
fi
python - "$PORT" <<'PY' 9>&-
import socket
import sys
with socket.socket() as sock:
    try:
        sock.bind(('127.0.0.1', int(sys.argv[1])))
    except OSError as exc:
        raise SystemExit(f'TensorBoard port unavailable: {exc}')
PY
RUN_DIR="$SCRIPT_DIR/legged_gym/logs/resmimic_suitcase/$NAME"
mkdir -p "$(dirname "$RUN_DIR")"
mkdir "$RUN_DIR"
mkdir "$RUN_DIR/tensorboard"
echo "$RUN_DIR" > "$STATE_DIR/run_dir"
echo "$PORT" > "$STATE_DIR/port"
echo "$INHIBITOR_NAME" > "$STATE_DIR/inhibitor"
nohup setsid --wait "${INHIBITOR[@]}" \
    bash "$SCRIPT_PATH" __worker "$RUN_DIR" "$PORT" "$NUM_ENVS" "$MAX_ITERATIONS" \
    < /dev/null > "$RUN_DIR/launcher.log" 2>&1 &
LAUNCHER_PID=$!
for ((i=0; i<150; i++)); do
    if [[ -f "$RUN_DIR/ready" ]] && active; then
        show_status
        echo "Stop: $SCRIPT_PATH stop"
        exit 0
    fi
    if [[ -f "$RUN_DIR/exit_code" ]] || ! kill -0 "$LAUNCHER_PID" 2>/dev/null; then
        cat "$RUN_DIR/launcher.log" >&2
        exit 1
    fi
    sleep 0.2
done
echo "Startup not confirmed; inspect $RUN_DIR/launcher.log" >&2
exit 1
