#!/usr/bin/env bash
# Display a local residual checkpoint in Isaac Gym; training is not started.
set -eo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
    cat <<'EOF'
Usage: ./eval.sh [checkpoint.pt | run_directory] [evaluation options]

Without a path, loads the newest numbered checkpoint in the last background run.
Examples:
  ./eval.sh
  ./eval.sh legged_gym/logs/resmimic_suitcase/RUN/model_16500.pt
  ./eval.sh --headless --eval_steps 20

Close the simulator window or press Esc to stop. W&B is not required.
EOF
    exit 0
fi
source "$SCRIPT_DIR/source_dev_setup.sh"
CHECKPOINT_INPUT=
if [[ $# -gt 0 && "$1" != --* ]]; then
    CHECKPOINT_INPUT=$1
    shift
fi
CHECKPOINT=$(python - "$SCRIPT_DIR" "$CHECKPOINT_INPUT" <<'PY'
import re
import sys
from pathlib import Path
root = Path(sys.argv[1])
value = sys.argv[2]
if value:
    path = Path(value).expanduser().resolve()
else:
    state = root/'legged_gym/logs/.tensorboard_bg/run_dir'
    if not state.exists():
        raise SystemExit('No previous background run; supply a checkpoint or run directory.')
    path = Path(state.read_text().strip())
if path.is_dir():
    models = [p for p in path.glob('model_*.pt') if re.fullmatch(r'model_\d+\.pt', p.name)]
    if not models:
        raise SystemExit(f'No checkpoints found in {path}')
    path = max(models, key=lambda p: int(p.stem.split('_')[-1]))
if not path.is_file():
    raise SystemExit(f'Checkpoint not found: {path}')
print(path)
PY
)
echo "Evaluating checkpoint: $CHECKPOINT"
exec python "$SCRIPT_DIR/legged_gym/legged_gym/scripts/play_residual.py" \
    --task g1_hoi --proj_name resmimic_suitcase --exptid "$(basename "$(dirname "$CHECKPOINT")")" \
    --checkpoint_path "$CHECKPOINT" --teacher_exptid None --eval_student \
    --wandb_entity '' --no_wandb --num_envs 1 --device cuda:0 "$@"
