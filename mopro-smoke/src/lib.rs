// Sprint-0 smoke test for the Foundation identity/humanity app's Phase 3
// (NFC + ZK) track. The crate's job:
//
//   1. Prove the Rust → mopro-ffi → UniFFI → .xcframework pipeline works on
//      iOS device + simulator, built from Xcode Cloud.
//   2. Prove a real Circom Groth16 proof (upstream's multiplier2, a*b=c)
//      can be generated on-device through `generate_circom_proof`.
//   3. Prove the Swift bindings (`CircomProofResult`, `CircomProof`,
//      `ProofLib`, `generate_circom_proof`, `verify_circom_proof`) are
//      type-compatible with what HomeView/Phase 3 will consume.
//
// Phase 3 swaps multiplier2 for the real NFC-bound circuit — that's a zkey
// + `set_circom_circuits!` entry change, not a toolchain rework.
//
// Layout mirrors what `mopro-cli init --adapter circom` emits for a fresh
// project (see mopro-cli 0.3.5 src/init/*.rs and src/template/circom/lib.rs).

mod error;
pub use error::MoproError;

// `mopro_ffi::app!()` expands to `extern crate mopro_ffi as uniffi;` +
// `uniffi::setup_scaffolding!()`. Do NOT also call `uniffi::setup_scaffolding!`
// directly — it would double-register the scaffolding symbols.
mopro_ffi::app!();

// `#[macro_use]` makes the `set_circom_circuits!` macro (defined inside
// circom.rs with #[macro_export]) resolvable as `crate::set_circom_circuits!`.
#[macro_use]
mod circom;
pub use circom::{
    generate_circom_proof, verify_circom_proof, CircomProof, CircomProofResult, ProofLib, G1, G2,
};

// Transpiled at build-time by build.rs via rust-witness from
// test-vectors/circom/multiplier2.wasm. Exposes `multiplier2_witness` as a
// plain Rust fn, so no WASM VM is needed on device.
mod witness {
    rust_witness::witness!(multiplier2);
}

// Register the circuits visible to `generate_circom_proof`. Keyed by the zkey
// filename (not path) so the Swift side can ship the zkey inside the app
// bundle and pass `Bundle.main.url(...)!.path` at call time.
crate::set_circom_circuits! {
    (
        "multiplier2_final.zkey",
        circom_prover::witness::WitnessFn::RustWitness(witness::multiplier2_witness)
    ),
}

// Smoke-test surface consumed by MoproSmokeBridge.hello() on the iOS side.
// Updating the string here requires rebuilding the xcframework on macOS.
#[uniffi::export]
pub fn mopro_smoke_hello() -> String {
    format!(
        "mopro-smoke v{} — mopro-ffi linked, multiplier2 registered.",
        env!("CARGO_PKG_VERSION")
    )
}
