uniffi::setup_scaffolding!();

// Two trivial entrypoints are enough to smoke-test the whole pipeline:
//  1. Rust compiles for every iOS target (device + simulator, arm64 + x86_64).
//  2. UniFFI's Swift bindgen emits a working module.
//  3. xcodebuild -create-xcframework fuses the static libs into an .xcframework.
//  4. The host app can `import MoproSmoke` and call into Rust.
//
// Once this is green, swapping `uniffi` for `mopro-ffi` (which layers Circom
// proof generation on top of the same UniFFI scaffolding) is a Cargo.toml
// change, not a toolchain rework.

#[uniffi::export]
pub fn mopro_smoke_hello() -> String {
    format!(
        "mopro-smoke v{} — UniFFI toolchain green. Next step: swap uniffi for mopro-ffi.",
        env!("CARGO_PKG_VERSION")
    )
}

#[uniffi::export]
pub fn mopro_smoke_sum(a: u32, b: u32) -> u32 {
    a.saturating_add(b)
}
