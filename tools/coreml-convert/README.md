# Core ML conversion harness

One-time, build-machine-only tools that convert third-party PyTorch face
models to Core ML `.mlpackage` files bundled into the iOS app. Runs locally
on macOS — never on a server, never on Firebase, never on the device.

## Outputs

Drop into `ios/FoundationMobile/Resources/`:

- `SilentFaceMiniFASNetV2.mlpackage` (~1MB) — Phase 5 anti-spoof, model A
- `SilentFaceMiniFASNetV1SE.mlpackage` (~1MB) — Phase 5 anti-spoof, model B
- `MobileFaceNet.mlpackage` (~2MB) — Phase 6 face embedder

Both anti-spoof models run together; their per-class softmax probabilities
are averaged in `AntiSpoofProducer.swift`.

## Re-run from a clean machine

```sh
pip install coremltools torch torchvision pillow numpy
git clone --depth 1 https://github.com/minivision-ai/Silent-Face-Anti-Spoofing.git
git clone --depth 1 https://github.com/Xiaoccer/MobileFaceNet_Pytorch.git
python3 convert-silent-face.py
python3 convert-mobilefacenet.py
```

The cloned upstream repos are **gitignored** — only the conversion scripts
and this README are tracked.

## Why these models

- **Silent-Face MiniFASNetV2 + V1SE**: minivision's MIT-licensed anti-spoof
  ensemble. Tiny (~1.5MB total), trained on print + replay attacks, well-
  documented operating points. Used as ensemble for robustness.
- **MobileFaceNet (Xiaoccer fork)**: 1.0M-param ArcFace-family face
  embedder, trained on CASIA-WebFace, evaluated on LFW. 128-dim embedding,
  cosine distance scoring. Small enough to bundle without bloating the IPA.

## License notes

- Silent-Face-Anti-Spoofing: MIT (minivision)
- MobileFaceNet weights: MIT (Xiaoccer)
- Conversion scripts: same license as the rest of foundation-mobile

The bundled `.mlpackage` outputs are derivative works. Both upstream repos
are MIT-licensed, attribution is preserved in each model's `author` and
`license` metadata fields (set during conversion).
