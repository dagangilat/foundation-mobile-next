# PoH Runtime Tiered-Fallback + Error Screens — Plan 2 (SEED / needs design)

> **Status:** SEED ONLY. Needs a brainstorming/design pass before it becomes an
> executable plan via superpowers:writing-plans. Do **not** start coding from this
> file — it captures the problem, the open decision, and the affected surface.

**Goal:** Implement the error/retry screens (poh-errors E1–E4) and, behind E2, the
real **tiered fallback**: a session that can't read the chip completes at a *lower*
trust tier at runtime instead of dead-ending.

## The hard part (why this is a separate plan)

Today the security tier is **baked at build time** — `hisec-global` (chip) and
`standardsec` (document-only) are *different builds*. Decision #1 (ratified) wants a
running High-Security session whose **NFC read fails** to finish as **Standard
Security** (document-photo face match), without rebuilding. That means decoupling:

- **achieved tier** (what the user actually completed this session) from
- **baked profile tier** (the edition's nominal maximum).

`VerifiedView` already renders the achieved tier + the "reach High Security" upgrade
hint — the UI is ready. The engine is not.

## Open decision (blocks everything)

**Is the chip mandatory, or is runtime downgrade allowed?** If chip stays mandatory,
E2 is a hard fail (retry / different doc only) and Plan 2 shrinks to the error
screens. If downgrade is allowed, the full fallback engine below is needed.
→ Resolve before writing the executable plan.

## Affected surface (for the design pass)

- `CaptureCoordinator.State` — a chip-read failure on a chip-capable profile must be
  able to re-route into the document-photo branch (`readyForDocumentPhoto` +
  `faceMatch` vs documentPhoto) rather than `.failed`.
- **Achieved-tier model** — a new runtime value distinct from `Profile.trustTier`,
  fed to `VerifiedView` (replace the current `profile.trustTier` read with the
  achieved tier). `TrustTierLadder` already handles any achieved tier.
- **Server proof acceptance** — will the backend accept a sub-chip (document-only)
  proof from a `hisec-global` client? Likely a CF / claims change. Out of iOS scope;
  must be confirmed.
- **Error screens** (poh-errors): E1 glare (live, non-blocking, in MRZ/doc capture),
  E2 chip-unreadable → tier fallback, E3 face-check retry, E4 timeout (progress
  saved). Map onto `CaptureCoordinator.FailureStage` + retry UI.
- **Upgrade path** — `VerifiedView`'s "Upgrade now" (currently unwired) would trigger
  a chip re-read to climb Standard → High. Needs a re-entry into the NFC funnel.

## Pre-work already in place (Plan 1)

- `Profile.trustTier`, `TrustTierLadder` (tested), `VerifiedView` Standard-state +
  upgrade hint, `documentNoun`. The verified screen will need **zero** changes beyond
  being handed the *achieved* tier instead of the baked one.
