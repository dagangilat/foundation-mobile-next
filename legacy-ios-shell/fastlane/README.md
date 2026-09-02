# fastlane

Declarative App Store Connect metadata + TestFlight upload for `foundation-mobile`. Runs locally or from Xcode Cloud.

## One-time: get an App Store Connect API key

1. Sign in to https://appstoreconnect.apple.com/access/api as an Account Holder (or ask one to add you as Admin).
2. **Keys** tab → **Generate API Key** (or **+**).
3. Name: `fastlane-foundation-mobile`. Access: `Admin` (needed for `deliver` + `produce`).
4. **Download API Key** — this gives you a `AuthKey_<KEYID>.p8` file. You get **exactly one chance** to download it. Save it somewhere safe (not in this repo).
5. Copy the **Key ID** (10 chars, shown on the keys page) and the **Issuer ID** (UUID at the top of the page).

## Local env (one-time)

Add to `~/.zshrc` (or a tool like direnv):

```bash
export APP_STORE_CONNECT_API_KEY_KEY_ID="ABC1234567"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="12345678-abcd-ef01-2345-6789abcdef01"
export APP_STORE_CONNECT_API_KEY_KEY_CONTENT="$(cat ~/.appstoreconnect/AuthKey_ABC1234567.p8)"
```

Never commit the `.p8` file. Never paste the key content into a PR or chat.

## Install fastlane

```bash
brew install fastlane
# or: gem install fastlane
```

## Lanes

```bash
cd ios

# One-time: create the App Store Connect app entry (replaces the manual ASC
# "New App" wizard). Skip if the entry already exists.
fastlane ios produce_app

# Push metadata + icon + screenshots (no binary):
fastlane ios deliver_metadata

# Build, sign, and upload a TestFlight build:
fastlane ios beta
```

## What's declarative here

- `metadata/en-US/*.txt` — name, subtitle, description, keywords, URLs, release notes.
- `metadata/review_information/*.txt` — reviewer contact + demo credentials + notes.
- `../FoundationMobile/Images.xcassets/AppIcon.appiconset/Icon-1024.png` — the 1024×1024 app icon.

## What's still manual (for now)

- **Screenshots** — drop them into `metadata/en-US/ios/*.png` before running `deliver_metadata`. Fastlane can also auto-capture via `snapshot` once we have UI tests.
- **Age rating** — set once via `deliver`'s first interactive run, then saved to `metadata/itunes_rating_config.json`.
- **App privacy (data collection questionnaire)** — ASC web UI only for now. Our answers are "does not collect" across every category (see the hard invariant in the canonical doc).
- **Pricing + availability** — set in the ASC UI (we're free everywhere for the MVP).

## Xcode Cloud integration

Xcode Cloud can call these lanes via `ios/ci_scripts/ci_post_xcodebuild.sh`. Add the three env vars above to the Xcode Cloud workflow's Environment tab. Don't commit them.
