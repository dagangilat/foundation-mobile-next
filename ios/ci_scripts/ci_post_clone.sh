#!/bin/sh
# Xcode Cloud — runs after `git clone`, before SPM resolution + xcodebuild.
# foundation-mobile is pure-SPM (see memory: project_spm_migration). Nothing
# to install here; placeholder for future environment-variable sanity checks
# (e.g. "fail fast if FIREBASE_APP_CHECK_DEBUG_TOKEN is empty in CI-Debug").

set -e

echo "foundation-mobile: ci_post_clone.sh — SPM-only project, no external installers to run."
