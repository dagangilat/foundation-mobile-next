# Third-party components and their licenses

This app statically links native zero-knowledge proving libraries that carry
copyleft obligations. This inventory is why the combined work ships under
GPL-3.0 (see LICENSE) with full source available in this public repository.

## Copyleft components — the reason this repo is GPL-3.0

| Component | License | Where it enters the build |
|---|---|---|
| `witnesscalc` (circuit witness calculators) | **GPL-3.0** | iOS: `ios/Frameworks/libwitnesscalc_*.a`, linked by `ios/FoundationMobile.xcodeproj/project.pbxproj`. Android: `android/app/src/main/cpp/lib/libwitnesscalc_*.so` + `lib/light/`, linked by `android/app/src/main/cpp/CMakeLists.txt`. |
| `rapidsnark` (Groth16 prover) | **LGPL-3.0** | iOS: `ios/Frameworks/librapidsnark.a`. Android: `android/app/src/main/cpp/lib/librapidsnark.so`. |
| `GMP` (GNU Multiple Precision) | LGPL-3.0 / GPL-2.0 dual | iOS: `ios/Frameworks/libgmp.a` (transitively via rapidsnark). |

Concrete iOS witness calculators present in the tree:
`libwitnesscalc_auth.a`, `libwitnesscalc_queryIdentity.a`,
`libwitnesscalc_faceRegistryNoInclusion.a`,
`libwitnesscalc_registerIdentityLight{160,224,256,384,512}.a`, and five
`libwitnesscalc_registerIdentity_*` variants.

## Permissive components

| Component | License |
|---|---|
| `rarime-ios-app`, `rarime-android-app`, `rarime-mobile-identity-sdk` (Rarimo Foundation) | MIT — see NOTICE |
| `libfq.a`, `libfr.a`, `libbionet.a` | Distributed with the upstream apps; treated as part of the Rarimo MIT distribution pending upstream clarification. See Open Decision OD-1. |
| Inter, Playfair Display (fonts) | SIL Open Font License 1.1 |

## Source availability

Complete corresponding source for the GPL-3.0 combined work is this
repository: https://github.com/dagangilat/foundation-mobile-next

Upstream sources for the native proving libraries:
- witnesscalc — https://github.com/0xPolygonID/witnesscalc
- rapidsnark  — https://github.com/iden3/rapidsnark
