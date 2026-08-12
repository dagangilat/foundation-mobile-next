# Foundation Mobile — next actions (2026-08-12)

Output of the 2026-08-10 → 2026-08-12 identity investigation, which ran mostly
in the `foundation` repo. This is the mobile-side residue.

**Source docs (all in `foundation`):**
`docs/2026-08-11-zkpassport-spike-findings.md` (measured results),
`docs/2026-08-11-zkpassport-backend-path-pricing.md`,
`docs/2026-08-12-identity-recommendations.md`,
`spikes/zkpassport/` (runnable harness + README).

---

## 1. The in-app passport lane — the big one, and NOT urgent

**Why it exists:** today a member leaves Foundation, installs RariMe from the
App Store, and scans a QR. That is the brand problem this whole investigation
started from. Foundation Mobile owning the flow is the fix.

**What changed:** ZKPassport is now the evidence-backed choice over Rarimo for
the in-app path, proven with working code rather than argument:

- Pure-Swift proving, **no GPL/LGPL anywhere** — Rarimo's prover is GPL-3.0
  `witnesscalc` + LGPL-3.0 `rapidsnark`, and GPL has no dynamic-link escape, so
  the Rarimo path needs a full prover rewrite (mopro/arkworks) before it can
  ship in a closed-source app.
- **~3.1 s one-time per document, then ~0.7 s per verification** (Apple Silicon
  Mac) — base subproofs are cached per document.
- **Deterministic nullifiers**, verified in circuit source and empirically:
  same passport from fresh state reproduces the same nullifier. Rarimo could
  not guarantee this.
- Backend is a **Cloud Function**, not a service tier (~190 ms in plain Node).

**Gates, in order — do not reorder:**

1. **Session binding.** With direct submit a bare proof is a bearer token;
   anyone holding one could claim that nullifier. ZKPassport ships a `bind`
   circuit for exactly this. **If this cannot be made to work, the approach
   fails** — spike it before anything else.
2. **iPhone hardware timing.** All numbers above are Mac. A phone is plausibly
   2–4× slower (~6–12 s one-time), but that is *extrapolation, not
   measurement*. Needs an Xcode app target around the existing harness plus
   provisioning. A paired iPhone 13 is available.
3. **Backend UltraHonk verification path.** Priced in the doc above; the wire
   format is already known and de-risked.

**Not urgent.** The L2 passport lane works on prod today via the RariMe QR
flow, and the Rarimo prod buildout is sunk cost, not avoidable spend.

**Two traps recorded from the spike** — both cost real time to find:

- `nargo` must be pinned to **1.0.0-beta.22** to match Swoirenberg
  `1.0.0-beta.22-1`. Installing latest silently produces circuits the Swift
  backend cannot load.
- Swoir prepends a 4-byte BE u32 public-input count that must be stripped
  before `bb` will verify (`[public_inputs…][proof_body…]` after a `4 + n*32`
  split).

## 2. Clone detection gap — real, and independent of vendor choice

`DocumentNFCReader.swift` / `ChipReading.swift` do **SOD → DG hash integrity
only**:

- **No Active Authentication, no Chip Authentication** — so a cloned chip is
  not detected. A byte-copy of a real chip carries a valid SOD and passes.
- The chain-to-CSCA check is **inactive by default** (no `csca-masterlist.pem`
  bundled) and **non-fatal when it does run** — `ChipReading.swift:74-81` logs
  and accepts on failure.

**No ZK passport stack closes this** — Rarimo, Self and ZKPassport all prove the
SOD signature chain, which is exactly what a clone reproduces. Only AA/CA
detects cloning, because they require a private key that cannot be extracted
from the chip. `NFCPassportReader` (already a dependency) exposes the
primitives.

**Calibration:** this is an *impersonation* risk (registering with someone
else's passport before they do), not a *Sybil* risk (a clone of the same
passport collides with the existing registration). Since the primary property
is one-person-one-vote, it is real but secondary — and the April architecture
doc's own decision matrix says an OSS stack suffices for Sybil resistance.
Adopting the ZK registration circuit would close the CSCA half cryptographically
as a side effect.

## 3. Repo hygiene — pre-existing, untouched by this investigation

- **Uncommitted `HANDOFF.md` rewrite** sitting in the working tree (replaces the
  2026-06-21 content with a 2026-08-10 session handoff). Not mine; commit or
  discard deliberately.
- Open PRs: **#4** (biometric gate on cold launch + passport biometric seal),
  **#1** (no-Mac iOS CI pipeline), **#17** / **#9** (dependabot). #4 and #1 have
  been open a while — decide or close.
- iOS CI and iOS TestFlight runs on `main` are red (pre-existing; local
  `xcodebuild` is the reliable fallback).

## 4. Explicitly not recommended

- **Do not switch the live QR lane.** It works, it is the only way in, it has
  real members.
- **Do not chase app size / SRS truncation.** The SRS need not be bundled, and
  users already download an entire third-party app today. Size is a progress
  bar, not a decision input.
- **Do not adopt ZKPassport's own app.** Still a third-party detour, and *less*
  sovereign than the `verificator-svc` Foundation already self-hosts — it
  requires domain registration at `dashboard.zkpassport.id` and a bridge relay
  with no published server.
