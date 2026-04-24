// rust-witness transpiles the circom WASM witness into a Rust function at
// build time so the release library can generate proofs without a WASM VM on
// device. The path is relative to CARGO_MANIFEST_DIR, matching upstream mopro
// template's convention (see mopro-cli 0.3.5 src/init/circom.rs BUILD_TEMPLATE).
fn main() {
    rust_witness::transpile::transpile_wasm("./test-vectors/circom".to_string());
}
