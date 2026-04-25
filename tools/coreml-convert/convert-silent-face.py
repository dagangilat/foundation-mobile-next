#!/usr/bin/env python3
"""
Convert minivision Silent-Face-Anti-Spoofing PyTorch weights to Core ML.

Output: ios/FoundationMobile/Resources/SilentFaceMiniFASNetV2.mlpackage
        ios/FoundationMobile/Resources/SilentFaceMiniFASNetV1SE.mlpackage

Both models take an 80x80 RGB image (values in [0,1]) and emit 3-class logits.
At runtime the iOS side averages the per-model softmax probabilities; class 1
is "real", classes 0 and 2 are spoof variants. Threshold tuned in the producer.
"""

import os
import sys
from pathlib import Path

import torch
import torch.nn as nn

REPO = Path(__file__).resolve().parent / "Silent-Face-Anti-Spoofing"
sys.path.insert(0, str(REPO))

from src.model_lib.MiniFASNet import MiniFASNetV2, MiniFASNetV1SE  # noqa: E402
from src.utility import get_kernel  # noqa: E402

import coremltools as ct  # noqa: E402

WEIGHTS = REPO / "resources" / "anti_spoof_models"
OUT_DIR = Path(__file__).resolve().parent.parent.parent / "ios" / "FoundationMobile" / "Resources"

MODELS = [
    {
        "weights": WEIGHTS / "2.7_80x80_MiniFASNetV2.pth",
        "ctor": MiniFASNetV2,
        "outname": "SilentFaceMiniFASNetV2",
        "input_size": (80, 80),
    },
    {
        "weights": WEIGHTS / "4_0_0_80x80_MiniFASNetV1SE.pth",
        "ctor": MiniFASNetV1SE,
        "outname": "SilentFaceMiniFASNetV1SE",
        "input_size": (80, 80),
    },
]


def load_model(ctor, weights_path, input_size):
    h, w = input_size
    model = ctor(conv6_kernel=get_kernel(h, w))
    state_dict = torch.load(weights_path, map_location="cpu", weights_only=True)
    first_key = next(iter(state_dict))
    if first_key.startswith("module."):
        state_dict = {k[len("module."):]: v for k, v in state_dict.items()}
    model.load_state_dict(state_dict)
    model.eval()
    return model


def convert(spec):
    model = load_model(spec["ctor"], spec["weights"], spec["input_size"])
    h, w = spec["input_size"]
    example = torch.zeros(1, 3, h, w)
    traced = torch.jit.trace(model, example, strict=False)

    image_input = ct.ImageType(
        name="image",
        shape=(1, 3, h, w),
        scale=1.0 / 255.0,
        bias=[0.0, 0.0, 0.0],
        color_layout=ct.colorlayout.RGB,
    )

    mlmodel = ct.convert(
        traced,
        inputs=[image_input],
        outputs=[ct.TensorType(name="logits")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS16,
        compute_precision=ct.precision.FLOAT16,
        compute_units=ct.ComputeUnit.CPU_AND_GPU,
    )

    mlmodel.short_description = (
        f"Silent-Face anti-spoof ({spec['ctor'].__name__}). "
        "Input: 80x80 RGB face crop, [0,1]. Output: 3-class logits."
    )
    mlmodel.author = "minivision (weights), Foundation (conversion)"
    mlmodel.license = "MIT"

    out_path = OUT_DIR / f"{spec['outname']}.mlpackage"
    if out_path.exists():
        import shutil
        shutil.rmtree(out_path)
    mlmodel.save(str(out_path))
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for spec in MODELS:
        print(f"Converting {spec['ctor'].__name__} ...")
        convert(spec)
