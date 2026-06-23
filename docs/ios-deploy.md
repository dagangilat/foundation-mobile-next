# iOS deploy — TestFlight

## TL;DR

**Deploy from the M5 Mac. It's free.** The GitHub Actions TestFlight workflow
costs money and exists only as a no-Mac fallback.

## Preferred path — local (free)

The Mac is the day-to-day release machine. Two equivalent options:

### A. One command (fastlane)
```bash
cd ios
bundle exec fastlane beta
```
Lane `beta` (`ios/fastlane/Fastfile`) archives, signs with the App Store
Connect API key, and uploads to TestFlight.

### B. Xcode GUI
1. Pick the edition: `ios/scripts/select-profile.sh <profile>` (e.g. `hisec-global`).
2. Scheme **FoundationMobile**, destination **Any iOS Device (arm64)**.
3. **Product → Archive** → Organizer → **Distribute App → TestFlight → Upload**.

Cost: $0 — runs on your machine + existing Apple Developer membership.

## Fallback path — GitHub Actions (PAID, guarded)

`.github/workflows/ios-testflight.yml` archives on a GitHub-hosted **macOS
runner, which is billed** (~$0.08/min; macOS minutes count ~10× against any
included quota — a full archive is several dollars to ~$10+ per run). Use it
only when no Mac is available.

It is deliberately hard to trigger by accident:
- **No tag trigger.** The old `push: tags: tf-*` trigger was removed, so a
  routine tag push can't start a paid run.
- **Manual dispatch + confirmation.** `workflow_dispatch` requires the
  `confirm` input to be set to `yes-run-paid-ci`. A free **ubuntu
  `confirm-gate` job** fails fast otherwise — no billed macOS runner starts
  unless you explicitly confirm.

To run it intentionally:
```bash
gh workflow run ios-testflight.yml --ref main \
  -f confirm=yes-run-paid-ci \
  -f profile=hisec-global \
  -f changelog="…"
```
or via the Actions tab → iOS TestFlight → Run workflow (set **confirm** to
`yes-run-paid-ci`).

> The other workflow, `ios-ci.yml`, is the no-Mac build/test pipeline (PR #1).
> It does **not** upload to TestFlight.
