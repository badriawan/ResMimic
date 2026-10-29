# RSL RL
Fast and simple implementation of RL algorithms, designed to run fully on GPU.
This code is an evolution of `rl-pytorch` provided with NVIDIA's Isaac GYM.

Only PPO is implemented for now. More algorithms will be added later.
Contributions are welcome.

## Setup

```
git clone https://github.com/leggedrobotics/rsl_rl
cd rsl_rl
pip install -e .
```

**Maintainer**: Nikita Rudin  
**Affiliation**: Robotic Systems Lab, ETH Zurich & NVIDIA
**Contact**: rudinn@ethz.ch  




## Added Command

Jalankan:

./train_tensorboard_bg.sh

Training berjalan di background tanpa W&B, tetap hidup saat terminal ditutup, dan menahan suspend menggunakan systemd-inhibit.

TensorBoard: http://localhost:6006

Cek dan hentikan:

./train_tensorboard_bg.sh status
./train_tensorboard_bg.sh stop

Model, log, dan event TensorBoard disimpan per run di:

legged_gym/logs/resmimic_suitcase/<nama_run>/

Sudah diuji dengan training singkat, metrik TensorBoard, dan fungsi stop. Semua proses pengujian sudah dihentikan.
  Worked for 5m 14s • 19:04

berapa banyak iterasi trainingnya?

Defaultnya 500.000 iterasi, dengan 4.096 lingkungan simulasi sekaligus.

Untuk mengubah jumlahnya, misalnya menjadi 10.000:

./train_tensorboard_bg.sh --max-iterations 10000
