"""Build the starting checkpoint for fine-tuning the eMamba-RTL-friendly Mamba-YOLO.

Takes a trained ReLU-delta checkpoint, converts layers 0-20 (LayerNorm -> LightNorm,
GELU -> SiLU), rescales every LightNorm weight so its average output scale matches the
LayerNorm it replaces (calibrate_lightnorm, COCO train images), and saves an Ultralytics
checkpoint whose yaml carries hw_norm / hw_act, so YOLO(<out>).train(...) rebuilds the
same architecture and loads these weights.

    PYTHONPATH=. python -m emamba_hw.prepare_hw_finetune --weights <relu best.pt> --out <init.pt>
"""

from __future__ import annotations

import argparse
from copy import deepcopy
from datetime import datetime
from pathlib import Path

import torch

import eval_compare_backends as ecb
from ultralytics import YOLO
from ultralytics.nn.modules.hw_ops import calibrate_lightnorm, convert
from ultralytics.nn.modules.mamba_yolo import SS2D

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--weights", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--calib-images", type=int, default=64)
    args = parser.parse_args()

    model = YOLO(str(args.weights)).model.float()
    for m in model.modules():
        if isinstance(m, SS2D):
            m.set_backend("v2_relu")
    changed = convert(model, norm="light", gelu_to_silu=True)
    model.yaml["hw_norm"], model.yaml["hw_act"] = "light", "silu"
    net = model.cuda().eval()
    data = ROOT / "ultralytics/cfg/datasets/coco.yaml"
    factors = calibrate_lightnorm(net, ecb.calibration_batches(data, args.calib_images, 640, 8, "0"))
    ckpt = {"date": datetime.now().isoformat(), "model": deepcopy(net).cpu().half(), "ema": None,
            "updates": None, "optimizer": None, "train_args": {}, "epoch": -1,
            "hw_convert": changed, "lightnorm_factors": factors, "source": str(args.weights)}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    torch.save(ckpt, args.out)
    print(f"saved {args.out}: {changed}, LightNorm factors {min(factors.values()):.2f}-{max(factors.values()):.2f}")


if __name__ == "__main__":
    main()
