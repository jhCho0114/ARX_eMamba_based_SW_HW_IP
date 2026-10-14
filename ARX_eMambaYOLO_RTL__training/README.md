# eMamba-YOLO 학습 (Mamba-YOLO-T, eMamba SSM 코어용)

Mamba-YOLO-T (COCO, 640×640) 를 eMamba RTL 에 맞게 다시 학습한 코드와 모델입니다.
[공개 Mamba-YOLO 레포](https://github.com/HZAI-ZJNU/Mamba-YOLO) 에 코드를 추가·수정한 것으로, 이 폴더에는 추가·수정한 파일만 들어 있습니다.

## 학습 순서

| 단계 | 내용 | 결과 (COCO mAP50-95) |
|---|---|---|
| 1 | `Mamba-YOLO-T-emamba.yaml` 로 처음부터 300 epoch 학습 (SSM delta 활성화 softplus → ReLU) | 0.4503 |
| 2 | `prepare_hw_finetune.py` 로 LightNorm / SiLU 구조로 변환 (LayerNorm → LightNorm, GELU → SiLU, LightNorm 스케일 보정) | 초기 체크포인트 |
| 3 | 30 epoch fine-tune → `mambayolo_t_relu_lightnorm.pt` | 0.4438 |

각 단계는 best.pt 를 사용했습니다 (1 단계 285 epoch, 3 단계 24 epoch).
이후 `quantization/full_ptq.py` 로 layer 0–20 을 INT8 로 양자화한 모델이 RTL (`../ARX_eMambaYOLO_RTL__under-developing`) 의 기준입니다.

## 폴더

`MambaYOLO_eMamba_reference/` 아래 파일과, Mamba-YOLO 레포에서 놓을 위치:

| 파일 | 레포 안 위치 | 내용 |
|---|---|---|
| `model/mamba_yolo.py` | `ultralytics/nn/modules/` | SS2D backend 추가 (`v2_relu`: ReLU delta 학습용, `emamba_relu`: 4 방향 단방향 reference) |
| `model/common_utils_mbyolo.py` | `ultralytics/nn/modules/` | `cross_selective_scan(..., delta_relu=True)` |
| `model/hw_ops.py` | `ultralytics/nn/modules/` | `LightNorm`, `HwSiLU`, piecewise linear SiLU, 변환 (`convert`) 과 LightNorm 보정 |
| `model/emamba_ss2d.py` | `ultralytics/nn/modules/` | eMamba 방식 SS2D reference (cross scan / merge, scan) |
| `model/emamba_quant.py` | `ultralytics/nn/modules/` | eMamba SSM 코어의 INT8 PTQ 모델 (2 의 거듭제곱 static scale) |
| `model/tasks.py` | `ultralytics/nn/tasks.py` | yaml 키 `ssm_forward_type`, `hw_norm`, `hw_act` 처리 |
| `model/Mamba-YOLO-T-emamba-hw.yaml` | `ultralytics/cfg/models/mamba-yolo/` | 3 단계 모델 구조 (LightNorm / SiLU) |
| `model/mambayolo_t_relu_lightnorm.pt` | — | 3 단계 결과 모델 |
| `train/mbyolo_train.py` | 레포 루트 | 학습 스크립트 |
| `train/prepare_hw_finetune.py` | `emamba_hw/` | 2 단계 변환 |
| `quantization/full_ptq.py` | `emamba_hw/` | layer 0–20 INT8 PTQ |
| `quantization/golden.py`, `golden_triton.py` | `emamba_hw/` | eMamba SSM 코어의 bit-accurate 모델 (PyTorch / 긴 시퀀스용 Triton, 결과 동일) |
| `quantization/mambayolo.py` | `emamba_hw/` | SS2D 를 eMamba golden 모델로 실행 (방향별 코어 4 회 호출, shift 보정) |
| `quantization/eval_compare_backends.py` | 레포 루트 | backend 비교 평가, 보정용 데이터 로더 |

`emamba_hw/` 에는 빈 `__init__.py` 를 하나 만들어 주세요.

## 실행 (레포 루트에서)

1 단계:

```bash
python mbyolo_train.py --task train --data ultralytics/cfg/datasets/coco.yaml \
  --config ultralytics/cfg/models/mamba-yolo/Mamba-YOLO-T-emamba.yaml \
  --device 0 --epochs 300 --batch_size 16 --workers 8 --imgsz 640 --optimizer SGD --amp
```

2 단계:

```bash
PYTHONPATH=. python -m emamba_hw.prepare_hw_finetune --weights <1단계 best.pt> --out <init.pt>
```

3 단계:

```bash
PYTHONPATH=. python train_hw_finetune.py
```

## 3 단계 hyperparameter

- 30 epoch, SGD (momentum 0.937, weight decay 5e-4)
- lr0 0.001, lrf 0.1, warmup 1 epoch
- batch 16, imgsz 640, AMP, close_mosaic 5
- 전체 설정은 args.yaml 참고

## 유의사항

- 공개 Mamba-YOLO 레포 기반으로 코드를 추가·수정했습니다.
- 레포에 포함된 ultralytics 와 selective_scan CUDA extension 이 필요합니다 (`cd selective_scan && pip install .`).
- 데이터셋 경로는 `ultralytics/cfg/datasets/coco.yaml` 에서 환경에 맞게 바꿔 주세요.
