#!/usr/bin/env python3
"""
Convert Xiaoccer/MobileFaceNet_Pytorch checkpoint to Core ML.

Output: ios/FoundationMobile/Resources/MobileFaceNet.mlpackage

Architecture: MobileFacenet (1.0M params, ~4MB)
Input:  112x96 RGB, normalized (pixel - 127.5) / 128.0
Output: 128-dim embedding (NOT L2-normalized; consumer normalizes)
"""

import sys
from pathlib import Path

import torch

REPO = Path(__file__).resolve().parent / "MobileFaceNet_Pytorch"
sys.path.insert(0, str(REPO))

from core.model import MobileFacenet  # noqa: E402

import coremltools as ct  # noqa: E402

CKPT = REPO / "model" / "best" / "068.ckpt"
OUT_DIR = Path(__file__).resolve().parent.parent.parent / "ios" / "FoundationMobile" / "Resources"


class FlattenWrap(torch.nn.Module):
    """Wrap MobileFacenet so the final reshape is `flatten(1)` instead of
    `view(size(0), -1)`. The latter trips coremltools 9 + torch 2.11 on
    `int(tensor.size(0))`. Output is identical."""
    def __init__(self, inner):
        super().__init__()
        self.inner = inner

    def forward(self, x):
        x = self.inner.conv1(x)
        x = self.inner.dw_conv1(x)
        x = self.inner.blocks(x)
        x = self.inner.conv2(x)
        x = self.inner.linear7(x)
        x = self.inner.linear1(x)
        return torch.flatten(x, 1)


def load_model():
    model = MobileFacenet()
    ckpt = torch.load(CKPT, map_location="cpu", weights_only=False)
    state_dict = ckpt["net_state_dict"]
    first_key = next(iter(state_dict))
    if first_key.startswith("module."):
        state_dict = {k[len("module."):]: v for k, v in state_dict.items()}
    model.load_state_dict(state_dict)
    model.eval()
    return FlattenWrap(model).eval()


def convert():
    model = load_model()
    H, W = 112, 96
    example = torch.zeros(1, 3, H, W)
    traced = torch.jit.trace(model, example, strict=False)

    image_input = ct.ImageType(
        name="image",
        shape=(1, 3, H, W),
        scale=1.0 / 128.0,
        bias=[-127.5 / 128.0, -127.5 / 128.0, -127.5 / 128.0],
        color_layout=ct.colorlayout.RGB,
    )

    mlmodel = ct.convert(
        traced,
        inputs=[image_input],
        outputs=[ct.TensorType(name="embedding")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS16,
        compute_precision=ct.precision.FLOAT16,
        compute_units=ct.ComputeUnit.CPU_AND_GPU,
    )

    mlmodel.short_description = (
        "MobileFaceNet embedding (Xiaoccer). "
        "Input: 112x96 RGB face crop. Output: 128-dim embedding (consumer L2-normalizes)."
    )
    mlmodel.author = "Xiaoccer (weights), Foundation (conversion)"
    mlmodel.license = "MIT"

    out_path = OUT_DIR / "MobileFaceNet.mlpackage"
    if out_path.exists():
        import shutil
        shutil.rmtree(out_path)
    mlmodel.save(str(out_path))
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    convert()
