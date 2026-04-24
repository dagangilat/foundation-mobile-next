// Copied verbatim from mopro-cli 0.3.5 src/template/init/src/error.rs. The
// mopro-cli template generates this file into every new project so the
// CircomError/Halo2Error/… variants are part of the UniFFI surface area even
// when only some adapters are enabled. We only exercise CircomError, but keep
// the full enum to stay source-compatible with the upstream template.

#[derive(Debug, thiserror::Error)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Error))]
pub enum MoproError {
    #[error("CircomError: {0}")]
    CircomError(String),
    #[error("Halo2Error: {0}")]
    Halo2Error(String),
    #[error("NoirError: {0}")]
    NoirError(String),
    #[error("GnarkError: {0}")]
    GnarkError(String),
}
