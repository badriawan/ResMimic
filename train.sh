#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/source_dev_setup.sh" || exit 1

WANDB_ENTITY=${1:-}
WANDB_ARGS=(--wandb_entity "$WANDB_ENTITY")
if [[ -z "$WANDB_ENTITY" ]]; then
    WANDB_ARGS+=(--no_wandb)
fi

python "$SCRIPT_DIR/legged_gym/legged_gym/scripts/train.py" --task "g1_hoi" \
            --proj_name "resmimic_suitcase" \
            --exptid "suitcase" \
            --device cuda:0 \
            --teacher_exptid None \
            --num_envs 4096 \
            "${WANDB_ARGS[@]}"
