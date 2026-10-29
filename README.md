# ResMimic: From General Motion Tracking to Humanoid Whole-Body Loco-Manipulation via Residual Learning

**Siheng Zhao**, Yanjie Ze, Yue Wang, C. Karen Liu†, Pieter Abbeel†, Guanya Shi†, Rocky Duan†  
*† Equal Advising · 2025*

[**Website**](https://resmimic.github.io/) · [**arXiv**](https://arxiv.org/abs/2510.05070) · [**Video**](https://www.youtube.com/watch?v=dadOH-TpbRk)


---

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Citation and Contact](#citation-and-contact)
- [Acknowledgments](#acknowledgments)

---

## Installation

One-time setup (creates environment and installs dependencies):

```bash
source setup_dev.sh
```

Each time you open a new terminal, activate the environment:

```bash
source source_dev_setup.sh
```

---

## Usage

### Training

Train the residual policy with the provided config. You need to pass your Weights & Biases entity (username or team):

```bash
./train.sh <wandb_entity>
```

Example: `./train.sh my_username`

### Background training with TensorBoard

Run locally without W&B, detached from the terminal and blocking sleep/idle while training:

```bash
./train_tensorboard_bg.sh
./train_tensorboard_bg.sh status
./train_tensorboard_bg.sh stop
```

Open TensorBoard at `http://localhost:6006`. Each run has its own directory in
`legged_gym/logs/resmimic_suitcase/`, containing checkpoints, `train.log`,
`tensorboard.log`, and TensorBoard events in `tensorboard/`. TensorBoard and the
sleep inhibitor stop when training exits. Forced shutdown is not prevented.
TensorBoard 2.14 (Python 3.8) requires `protobuf<5` for its dashboard API;
this compatibility constraint is included in `rsl_rl` dependencies.

Optional settings, including a short trial:

```bash
./train_tensorboard_bg.sh --name trial --num-envs 16 --max-iterations 2 --port 6007
```

Uses `systemd-inhibit` (systemd), falling back to `gnome-session-inhibit` if
systemd denies permission. If neither inhibitor works, training does not start.
The GNOME fallback protects against desktop-session suspend/idle while that
session remains logged in. Run from your logged-in desktop session. Also requires
`flock`, `setsid`, and the project environment.

### Evaluation

Display the latest local checkpoint from the last background run:

```bash
./eval.sh
```

Or pass a specific checkpoint: `./eval.sh /path/to/model_16500.pt`.
The simulator remains open until its window is closed or Esc is pressed.
For a short headless check: `./eval.sh --headless --eval_steps 20`.
Evaluation uses the residual checkpoint plus the provided base policy, without W&B.

Use `./eval.sh --record_video` to save a finite video. The Python evaluator also
retains its W&B loading arguments for online runs.

To view saved graphs after stopping training, run `./tensorboard.sh --port 6008`
in a separate terminal and open `http://localhost:6008/#scalars`.
Stop that server with Ctrl+C; this does not start or stop training or evaluation.

---

## Citation and Contact

If you find this work useful, please cite:

```bibtex
@article{zhao2025resmimic,
title={ResMimic: From General Motion Tracking to Humanoid Whole-body Loco-Manipulation via Residual Learning}, 
author={Siheng Zhao and Yanjie Ze and Yue Wang and C. Karen Liu and Pieter Abbeel and Guanya Shi and Rocky Duan},
year={2025},
journal= {arXiv preprint arXiv:2510.05070}
}
```
And also consider citing the related works:
```bibtex
@article{ze2025twist2,
title={TWIST2: Scalable, Portable, and Holistic Humanoid Data Collection System},
author= {Yanjie Ze and Siheng Zhao and Weizhuo Wang and Angjoo Kanazawa and Rocky Duan and Pieter Abbeel and Guanya Shi and Jiajun Wuand C. Karen Liu},
year= {2025},
journal= {arXiv preprint arXiv:2511.02832}
}
```

Questions: [sihengz@usc.edu](mailto:sihengz@usc.edu)

---

## Acknowledgments

This codebase is built on [TWIST2](https://github.com/amazon-far/TWIST2).


## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This project is licensed under the Apache-2.0 License.

This repository builds upon third-party open-source projects, including
[`legged_gym`](https://github.com/leggedrobotics/legged_gym) and
[`rsl_rl`](https://github.com/leggedrobotics/rsl_rl). These components have been modified to support our use case. The original
LICENSE files in their respective subdirectories are retained and continue to
govern those portions of the code. All rights and attribution remain with the
original authors in accordance with their licenses.

