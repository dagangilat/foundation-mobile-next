// Thin wrapper around UniFFI's bindgen CLI. Lives in a sibling workspace
// package (not inside mopro_smoke) so the direct `uniffi` dep doesn't
// conflict with `mopro_ffi::app!()`'s `extern crate mopro_ffi as uniffi;`
// alias in mopro_smoke/src/lib.rs. See ../Cargo.toml workspace comment.
fn main() {
    uniffi::uniffi_bindgen_main();
}
