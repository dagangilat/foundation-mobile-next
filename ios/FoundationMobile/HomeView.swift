import SwiftUI

struct HomeView: View {
    let claims: Claims

    @StateObject private var firestore = FirestoreService.shared
    @StateObject private var attestation = AttestationCoordinator.shared
    @State private var proofSmoke: SmokeProofResult = .skipped
    @StateObject private var capture = CaptureCoordinator.shared
    @StateObject private var pairing = PairingCoordinator.shared
    @State private var isShowingQRScanner: Bool = false
    @State private var isShowingSupport: Bool = false
    // 2026-04-26 security review M-CRIT-4: explicit Art. 9 / BIPA
    // §15(b) consent gate before any biometric capture. Sheet driver
    // for BiometricConsentView. State is local; the source of truth
    // is users/{uid}/legal_consent/biometric-processing_v1.
    @State private var isShowingBiometricConsent: Bool = false
    @StateObject private var biometricConsent = BiometricConsentState.shared
    // P0-3: gate Verify-humanity / Connect-to-Foundation on real network
    // reachability so the user gets immediate "Waiting for network…" copy
    // instead of waiting for Firebase callables to time out 60s into a tap.
    @StateObject private var reachability = Reachability.shared
    // Persisted across app launches — flips true when the user taps
    // "Connect to Foundation" after humanity is anchored. Subsequent
    // cold launches skip the Connect tap entirely and go straight into
    // WebHomeView (still pre-warmed under the hood). Reset to false on
    // sign-out via UserDefaults.removeObject so a different user signing
    // in on the same device sees the Connect CTA and can re-affirm
    // entry. Originally `@State` (session-only) — changed 2026-04-28
    // because the per-launch tap was costing 1-2 s plus a UX beat in
    // the relogin path that returning users found disorienting.
    @AppStorage("foundationHasConnected") private var hasConnected: Bool = false
    // NavigationStack path for programmatic push into CaptureView. Lets
    // the "Verify humanity" Button gate navigation behind a Face ID
    // prompt instead of the implicit NavigationLink push. Empty path =
    // root preVerifyHome; [.capture] = pushed into the capture flow.
    @State private var captureNavigationPath = NavigationPath()

    private var ringText: String? {
        let ring = firestore.userDoc?.ring ?? claims.ring
        guard let ring else { return nil }
        return Theme.ringLabels[ring] ?? "Ring \(ring)"
    }

    // True once registration has completed AND the on-chain anchor has
    // landed (Firestore signal — survives app restart). Drives the swap
    // to WebHomeView so the user no longer sees the Verify-humanity CTA
    // or the technical readouts. Falls back to the live capture state
    // for the brief queued→anchored window before Firestore propagates.
    private var humanityVerified: Bool {
        if firestore.humanityVerified { return true }
        if case .completed(let r) = capture.anchorStatus, r.status == "anchored" {
            return true
        }
        return false
    }

    var body: some View {
        // Aggressive pre-warm: mount WebHomeView the moment HomeView
        // appears for any signed-in user, hidden behind preVerifyHome,
        // regardless of humanity verification state. WKWebView starts
        // its WebContent process (~2 s cold), parses the 3.9 MB React
        // bundle (~2-3 s), runs `mintWebSessionToken` (~1 s), and the
        // bridge sign-in (signInWithCustomToken inside WebView) — all
        // while the user is on the iOS verify-humanity flow. By the
        // time they tap "Connect to Foundation", hasConnected flips,
        // opacity flips, and they see the already-signed-in foundation
        // home with no Landing flash, no "Connecting from your phone…"
        // spinner.
        //
        // For users without humanity yet, the WebView's AccessGate
        // redirects to /register internally. Once humanity is anchored
        // on chain, the web's voter-proof listener picks it up and
        // AccessGate transitions to home — also pre-warmed by the time
        // they tap Connect. Network cost is one extra mint+bridge per
        // session, which is negligible.
        ZStack {
            WebHomeView(claims: claims, pairing: pairing)
                .opacity(hasConnected ? 1 : 0)
                .allowsHitTesting(hasConnected)
            if !hasConnected {
                preVerifyHome
            }
        }
        .onAppear {
            firestore.observeUser(uid: claims.uid)
            attestation.start()
        }
        .task {
            proofSmoke = await MoproSmokeBridge.runMultiplier2Smoke()
        }
        .sheet(isPresented: $isShowingSupport) {
            SupportSheet(
                attestation: attestation,
                capture: capture,
                proofSmoke: proofSmoke
            )
        }
        .sheet(isPresented: $isShowingBiometricConsent) {
            BiometricConsentView(
                onAccept: {
                    isShowingBiometricConsent = false
                    // Re-enter the gate so the rest of beginVerifyHumanity
                    // (Face ID prompt + capture push) runs in one tap.
                    await beginVerifyHumanity()
                },
                onCancel: {
                    isShowingBiometricConsent = false
                }
            )
            .interactiveDismissDisabled()
        }
    }

    private var preVerifyHome: some View {
        NavigationStack(path: $captureNavigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    PillarsHero()
                    ringCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            // Hide the navigation bar on this root screen so the safe-area
            // handling matches LoadingView's plain-VStack layout. Without
            // this, NavigationStack reserves bar height even when no
            // title is set, pushing the hero ~44pt lower than the splash
            // and breaking the splash → home pixel-match. Capture uses
            // its own dedicated screen via .navigationDestination, so
            // hiding the bar here doesn't affect that flow.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeView.Route.self) { route in
                switch route {
                case .capture:
                    CaptureView()
                }
            }
        }
    }

    enum Route: Hashable {
        case capture
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.brandGreen)
                HStack(spacing: 0) {
                    Text("Found").foregroundStyle(.white)
                    Text("ation").foregroundStyle(Theme.brandGreen)
                }
                .font(.system(size: 22, weight: .bold))
            }
            Spacer()
            Button {
                Task { try? await AuthService.shared.signOut() }
            } label: {
                if pairingActive {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign out")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Theme.brandGreen)
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(Theme.muted)
                }
            }
            .accessibilityLabel(pairingActive
                ? "Sign out — phone is the master key for the paired desktop"
                : "Sign out")
        }
    }

    // True when there's an active or in-flight pairing — sign-out is the
    // single most important affordance because the phone session is what
    // a desktop pair trusts. Promoting it visually reinforces "this phone
    // is your master key" so the user keeps it close.
    private var pairingActive: Bool {
        switch pairing.state {
        case .paired, .claiming, .releasing, .needsFreshAuth:
            return true
        case .idle, .failed:
            return false
        }
    }

    // SolanaPill + PillarsHero live in PillarsHero.swift — shared with
    // LoadingView so the splash and the post-sign-in hero are guaranteed
    // identical pixel-for-pixel.

    private var ringCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Signed in")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(claims.email ?? claims.uid)
                .font(.callout)
                .foregroundStyle(.white)
            if let ringText {
                Text(ringText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.brandGreen)
                    .padding(.top, 4)
            } else {
                Text("Ring pending — awaiting first-sign-in claim")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
            humanityStatusLine
                .padding(.top, 12)
            verificationBadges
                .padding(.top, 10)
            verifyHumanityButton
                .padding(.top, 8)
            // Pair-desktop UI gated by AppConfig.shared.pairing.enabled.
            // Code path stays compiled — flipping back is a profile-
            // JSON edit, not a code change. See foundationmobile.json
            // (and the matching FEATURES.desktopPairing flag in
            // foundation-global/evoting-frontend/src/config/features.json).
            if AppConfig.shared.pairing.enabled {
                pairingRow
                    .padding(.top, 4)
            }
            supportButton
                .padding(.top, 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        .cornerRadius(12)
    }

    // Single user-facing line for humanity-verification state. The raw
    // technical detail (App Attest, mopro, commitment hash, anchor
    // status) lives in SupportSheet behind the Support button — this
    // row stays narratively legible.
    @ViewBuilder
    private var humanityStatusLine: some View {
        HStack(spacing: 8) {
            Image(systemName: humanityFriendlyIcon)
                .font(.callout)
                .foregroundStyle(humanityFriendlyColor)
            Text(humanityFriendlyLabel)
                .font(.callout)
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var humanityFriendlyIcon: String {
        switch capture.state {
        case .sealed: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .verifying, .scanningPassport, .readyForPose, .readyForPassport,
             .passportReady, .readyForDocumentPhoto, .documentPhotoReady,
             .readyForVerification:
            return "hourglass"
        case .needsAttestation: return "lock.shield"
        case .unsupported: return "iphone.slash"
        case .idle: return "person.crop.circle.badge.questionmark"
        }
    }

    private var humanityFriendlyColor: Color {
        switch capture.state {
        case .sealed: return Theme.brandGreen
        case .failed: return .orange
        default: return Theme.muted
        }
    }

    private var humanityFriendlyLabel: String {
        // Returning user (anchored from a prior session, no fresh capture
        // this run). Surfaces the Connect call-to-action so they don't
        // see "Verify humanity" again.
        if humanityVerified, case .idle = capture.state {
            return "Humanity verified — tap Connect to enter Foundation"
        }
        switch capture.state {
        case .idle:
            if isAttested { return "Verify humanity to start using Foundation" }
            return "Setting up your secure session…"
        case .needsAttestation: return "Setting up your secure session…"
        case .unsupported: return "Verification needs a real iPhone (not a simulator)"
        case .readyForPose, .readyForPassport, .scanningPassport, .passportReady,
             .readyForDocumentPhoto, .documentPhotoReady, .readyForVerification:
            return "Verification in progress — finish in the camera step"
        case .verifying: return "Sealing your humanity proof…"
        case .sealed:
            switch capture.anchorStatus {
            case .completed(let r) where r.status == "anchored":
                return "Humanity verified — tap Connect to enter Foundation"
            case .pending, .completed:
                return "Humanity sealed — anchoring on devnet…"
            case .failed:
                return "Humanity sealed — anchor retrying"
            case .notAttempted:
                return "Humanity sealed"
            }
        case .failed: return "Verification didn't complete — tap to try again"
        }
    }

    // MARK: - Verification badges
    //
    // Visual roll-call of every protection layer the active profile
    // demands, plus the on-chain anchor that always applies. States
    // drive color: locked (muted) before the flow starts, pending
    // (orange) while in flight, verified (brand green) when the seal
    // (or anchor) lands. We worked hard to get here — show it off.

    private enum BadgeState {
        case locked, pending, verified, failed, caution

        var fg: Color {
            switch self {
            case .verified: return Theme.brandGreen
            case .pending:  return .orange
            case .failed:   return .orange
            case .caution:  return .yellow
            case .locked:   return Theme.muted
            }
        }
        var bg: Color {
            switch self {
            case .verified: return Theme.brandGreen.opacity(0.14)
            case .pending:  return Color.orange.opacity(0.12)
            case .failed:   return Color.orange.opacity(0.16)
            case .caution:  return Color.yellow.opacity(0.12)
            case .locked:   return Theme.surface
            }
        }
        var border: Color {
            switch self {
            case .verified: return Theme.brandGreen.opacity(0.45)
            case .pending:  return Color.orange.opacity(0.45)
            case .failed:   return Color.orange.opacity(0.55)
            case .caution:  return Color.yellow.opacity(0.45)
            case .locked:   return Theme.border
            }
        }
        var iconSuffix: String {
            switch self {
            case .verified: return "checkmark.circle.fill"
            case .pending:  return "clock.fill"
            case .failed:   return "exclamationmark.triangle.fill"
            case .caution:  return "exclamationmark.shield.fill"
            case .locked:   return "lock.fill"
            }
        }
    }

    private struct BadgeData: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let state: BadgeState
    }

    @ViewBuilder
    private var verificationBadges: some View {
        let badges = activeBadges
        if !badges.isEmpty {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(badges) { badge in
                    badgePill(badge)
                }
            }
        }
    }

    private func badgePill(_ b: BadgeData) -> some View {
        HStack(spacing: 8) {
            Image(systemName: b.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(b.state.fg)
                .frame(width: 16)
            Text(b.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(b.state.fg)
                .lineLimit(1)
            Spacer(minLength: 4)
            Image(systemName: b.state.iconSuffix)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(b.state.fg)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(b.state.bg)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(b.state.border, lineWidth: 1))
        .cornerRadius(8)
    }

    private var activeBadges: [BadgeData] {
        var out: [BadgeData] = []
        let profile = AppConfig.shared.profile

        // Icon picks mirror the hero's bold-filled aesthetic (waveform,
        // wallet.pass.fill, cart.fill). Each one chosen for one-glance
        // semantic legibility; all SF Symbol fills, single-color.

        // App Attest — always required. Mirrors Foundation's shield logo.
        out.append(BadgeData(
            icon: "lock.shield.fill",
            label: "App Attest",
            state: appAttestBadgeState
        ))

        // Liveness — bold filled face = real, present human.
        if profile.requires(.liveness) {
            out.append(BadgeData(
                icon: "face.smiling.inverse",
                label: "Liveness",
                state: captureBadgeState
            ))
        }

        // ePassport NFC — book of pages = passport silhouette.
        if profile.requires(.nfcZk) {
            out.append(BadgeData(
                icon: "book.pages.fill",
                label: "ePassport",
                state: captureBadgeState
            ))
        }

        // Anti-spoof — open eye = "we see the real you, not a print".
        if profile.requires(.antiSpoof) {
            out.append(BadgeData(
                icon: "eye.fill",
                label: "Anti-spoof",
                state: captureBadgeState
            ))
        }

        // Face match — filled person + checkmark = identity confirmed.
        if profile.requires(.faceMatch) {
            out.append(BadgeData(
                icon: "person.crop.circle.fill.badge.checkmark",
                label: "Face match",
                state: captureBadgeState
            ))
        }

        // On-chain anchor — chain link = Solana commitment landed.
        out.append(BadgeData(
            icon: "link.circle.fill",
            label: "On-chain",
            state: anchorBadgeState
        ))

        return out
    }

    private var appAttestBadgeState: BadgeState {
        switch attestation.state {
        case .attested, .alreadyAttested: return .verified
        case .attesting, .idle:           return .pending
        case .failed:                     return .failed
        case .unsupported:                return .locked
        case .unattested:                 return .caution
        }
    }

    // Single badge state for all capture-driven phases (liveness +
    // ePassport + anti-spoof + face-match). They pass or fail together
    // because the seal is atomic — partial sealing is impossible. If
    // the seal landed, every required phase passed; if it failed,
    // we don't get to claim any individual phase.
    //
    // Returning users (humanityVerified from Firestore) keep these
    // badges green even after a fresh launch where capture.state has
    // reset to .idle — the on-chain anchor is the source of truth that
    // the seal landed, so the constituent phases must have passed.
    private var captureBadgeState: BadgeState {
        if humanityVerified { return .verified }
        switch capture.state {
        case .sealed: return .verified
        case .failed: return .failed
        case .readyForPose, .readyForPassport, .scanningPassport,
             .passportReady, .readyForDocumentPhoto, .documentPhotoReady,
             .readyForVerification, .verifying:
            return .pending
        case .idle, .needsAttestation, .unsupported: return .locked
        }
    }

    private var anchorBadgeState: BadgeState {
        if humanityVerified { return .verified }
        switch capture.anchorStatus {
        case .completed(let r):
            switch r.status {
            case "anchored":      return .verified
            case "queued":        return .pending
            case "anchor-failed": return .failed
            default:              return r.accepted ? .verified : .pending
            }
        case .pending: return .pending
        case .failed:  return .failed
        case .notAttempted: return .locked
        }
    }

    @ViewBuilder
    private var supportButton: some View {
        Button {
            isShowingSupport = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lifepreserver")
                    .font(.system(size: 15, weight: .semibold))
                Text("Support & diagnostics")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.muted)
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
        }
        .accessibilityLabel("Open support and diagnostics")
        .accessibilityHint("Reveals device technical state and lets you send it to Foundation Support without sharing personal data.")
    }

    @ViewBuilder
    private var captureRow: some View {
        HStack(spacing: 8) {
            Image(systemName: captureIcon)
                .font(.caption)
                .foregroundStyle(captureColor)
            Text(captureLabel)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
        }
        if case .sealed(let commitment) = capture.state {
            VStack(alignment: .leading, spacing: 2) {
                Text(shortHash(commitment.commitmentHashHex))
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.brandGreen)
                Text(kindChecklist(commitment.artifactKinds))
                    .font(.caption2.monospaced())
                    .foregroundStyle(Theme.muted)
            }
            .padding(.leading, 20)
        }
    }

    private var captureIcon: String {
        switch capture.state {
        case .idle: return "camera"
        case .unsupported: return "iphone.slash"
        case .needsAttestation: return "hourglass"
        case .readyForPose, .readyForPassport, .scanningPassport, .passportReady,
             .readyForDocumentPhoto, .documentPhotoReady, .readyForVerification, .verifying:
            return "hourglass"
        case .sealed: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var captureColor: Color {
        switch capture.state {
        case .sealed: return Theme.brandGreen
        case .failed: return .orange
        default: return Theme.muted
        }
    }

    private var captureLabel: String {
        switch capture.state {
        case .idle: return "Humanity — not yet verified"
        case .unsupported: return "Humanity — requires real device"
        case .needsAttestation: return "Humanity — App Attest pending"
        case .readyForPose(_, let captured, let total):
            return "Humanity — capturing poses (\(captured)/\(total))"
        case .readyForPassport: return "Humanity — ready to scan passport"
        case .scanningPassport: return "Humanity — scanning passport…"
        case .passportReady: return "Humanity — passport scanned, ready to verify"
        case .readyForDocumentPhoto: return "Humanity — ready to capture document"
        case .documentPhotoReady: return "Humanity — document photo captured, ready to verify"
        case .readyForVerification: return "Humanity — ready to verify"
        case .verifying(let phase):
            return phase == .signing ? "Humanity — signing…" : "Humanity — sealing…"
        case .sealed: return "Humanity — sealed · \(anchorSuffix)"
        case .failed(_, let msg): return "Humanity — failed: \(msg)"
        }
    }

    // Trailing status for the sealed row — visible once the commitment lands
    // locally, then updates live as the server-audit call returns. The
    // callable returns immediately with status:"queued" and the on-chain
    // write happens async (Cloud Tasks → identity_commitments program on
    // devnet). Firestore onSnapshot subscription for live queued→anchored
    // transitions is the next polish.
    private var anchorSuffix: String {
        switch capture.anchorStatus {
        case .notAttempted: return "audit pending"
        case .pending: return "auditing…"
        case .completed(let r):
            switch r.status {
            case "anchored":
                if let slot = r.slot { return "anchored · slot \(slot)" }
                return "anchored"
            case "queued":
                return "queued · anchoring on devnet…"
            case "anchor-failed":
                return "anchor failed — retrying"
            default:
                // Legacy stub or unknown status — fall back to accepted/reason.
                if r.accepted, let slot = r.slot { return "anchored · slot \(slot)" }
                if let reason = r.reason, !reason.isEmpty { return reason }
                return r.accepted ? "sealed" : "audit rejected"
            }
        case .failed(let msg): return "audit failed: \(msg.prefix(40))"
        }
    }

    // Three-stage CTA: Verify (pre-PoH) → Anchoring (sealed) → Connect (anchored).
    // App Attest failure shorts to a retry button regardless of stage.
    private enum VerifyStage {
        case attestFailed(String)
        case attestPending
        case verify
        case verifying          // PoH in flight (capture state non-idle, non-sealed)
        case anchorPending      // sealed, waiting for chain anchor
        case connect            // anchored, ready to enter Foundation
    }

    private var verifyStage: VerifyStage {
        if case .failed(let msg) = attestation.state { return .attestFailed(msg) }
        // Standard tier requires .attested / .alreadyAttested before
        // proceeding. Unattested tier (user skipped, simulator) is
        // explicitly allowed past the gate — server stamps artifacts
        // with attestationTier="unattested" so downstream consumers can
        // weigh trust accordingly. Only block on .attesting / .idle
        // here.
        if !isAttested && attestation.tier != .unattested { return .attestPending }
        if humanityVerified { return .connect }
        switch capture.state {
        case .sealed: return .anchorPending
        case .readyForPose, .readyForPassport, .scanningPassport, .passportReady,
             .readyForDocumentPhoto, .documentPhotoReady, .readyForVerification, .verifying:
            return .verifying
        default: return .verify
        }
    }

    @ViewBuilder
    private var verifyHumanityButton: some View {
        switch verifyStage {
        case .attestFailed(let msg):
            // App Attest failed — surface the error and let the user retry
            // without delete-and-reinstall.
            Button {
                attestation.retry()
            } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text("Retry secure session")
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(.black.opacity(0.75))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(Color.orange)
                .cornerRadius(10)
            }
        case .attestPending:
            VStack(spacing: 10) {
                disabledGreenButton(text: "Verify humanity — App Attest pending")
                if attestation.canSkipAttestation {
                    // Surfaced 10s into .attesting so the user is never
                    // staring at an unresponsive screen on simulator
                    // runs, network captive portals, or a misconfigured
                    // App Attest entitlement. Skipping drops the
                    // coordinator into .failed with copy that flags the
                    // session as unattested — the broader unattested-
                    // tier behavior (server-side flagging, tighter
                    // freshness, biometric seal) is in the follow-on
                    // two-tier App Attest task.
                    Button {
                        attestation.skipAttestation()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "forward.circle")
                                .font(.caption)
                            Text("Continue without attestation")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.muted)
                    }
                    .accessibilityLabel("Continue without device attestation")
                }
            }
        case .verify:
            if !reachability.isReachable {
                disabledGreenButton(text: "Waiting for network…")
            } else {
                Button {
                    Task { await beginVerifyHumanity() }
                } label: {
                    primaryGreenButtonLabel(text: "Verify humanity")
                }
            }
        case .verifying:
            // CaptureView dismissed at .verifying — spinner here is the
            // user's signal that the heavy work (App Attest assertions
            // per artifact + final seal) is still running in the
            // background while they're free to navigate the home
            // screen. Capture / anchor badges are also pulsing pending.
            backgroundProgressButton(text: "Sealing your verification…")
        case .anchorPending:
            backgroundProgressButton(text: "Anchoring on devnet…")
        case .connect:
            if !reachability.isReachable {
                disabledGreenButton(text: "Waiting for network…")
            } else {
                Button {
                    hasConnected = true
                } label: {
                    primaryGreenButtonLabel(text: "Connect to Foundation")
                }
            }
        }
    }

    private func primaryGreenButtonLabel(text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.brandGreen)
            .cornerRadius(10)
    }

    // Spinner-on-pill treatment for stages where heavy work runs in
    // the background while the user is free on the home screen
    // (sealing after CaptureView dismisses; anchoring on devnet). Same
    // green pill as the primary CTA — visually it remains the "next
    // step" surface, just non-interactive while we work.
    private func backgroundProgressButton(text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.black)
                .scaleEffect(0.8)
            Text(text)
                .font(.headline)
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.brandGreen)
        .cornerRadius(10)
        .opacity(0.7)
    }

    private func disabledGreenButton(text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.brandGreen)
            .cornerRadius(10)
            .opacity(0.5)
    }

    private var isAttested: Bool {
        switch attestation.state {
        case .attested, .alreadyAttested: return true
        default: return false
        }
    }

    /// Entry gate for the humanity-verification flow. A Face ID prompt
    /// happens HERE — before camera opens for ~40 seconds of pose
    /// capture + NFC + anti-spoof — so the user authorizes the session
    /// once, up-front, instead of being prompted post-flow when the
    /// camera was already locked on their face. Cancellation by the
    /// user (or no enrolled biometric) skips the gate but still allows
    /// proceeding; server already gates artifact trust by attestation
    /// tier so an unsealed verification simply lands as unattested.
    /// Future: per-gate seals (post-NFC, pre-final-seal) per
    /// docs/connect-and-pairing-flows.md follow-up.
    @MainActor
    private func beginVerifyHumanity() async {
        // 2026-04-26 security review M-CRIT-4: gate on explicit
        // biometric-processing consent before triggering Art. 9
        // capture. Local cache is just a fast path; the server-side
        // legal_consent doc is the authoritative record. If the user
        // has never consented at this version, present the consent
        // sheet — beginVerifyHumanity is re-invoked from onAccept.
        if !biometricConsent.hasAcceptedCurrentVersion() {
            isShowingBiometricConsent = true
            return
        }
        guard BiometricSealer.shared.isAvailable else {
            captureNavigationPath.append(Route.capture)
            return
        }
        // Sign uid + the current second so the signature is bound to
        // this session, not a replayable static value. Server doesn't
        // verify this today — the per-anchor seal model is the future
        // place for cryptographic binding — but the prompt itself is
        // the load-bearing UX gate.
        let nowSec = Int64(Date().timeIntervalSince1970)
        let payload = Data("\(claims.uid):\(nowSec)".utf8)
        do {
            _ = try await BiometricSealer.shared.sign(
                payload: payload,
                prompt: "Authorize identity verification"
            )
        } catch BiometricSealError.userCancelled {
            return  // user explicitly bailed; don't navigate
        } catch BiometricSealError.keyInvalidated {
            // Biometric set changed since enrollment — reset and ask
            // the user to re-tap. Don't auto-retry the prompt; that
            // would feel like the OS is misbehaving.
            BiometricSealer.shared.resetKey()
            return
        } catch {
            // Generic failure — log and proceed. The capture flow's
            // own per-step protections still apply.
            print("[HomeView] biometric gate skipped: \(error)")
        }
        captureNavigationPath.append(Route.capture)
    }

    private func shortHash(_ hex: String) -> String {
        guard hex.count > 16 else { return hex }
        let first = hex.prefix(12)
        let last = hex.suffix(4)
        return "\(first)…\(last)"
    }

    private func kindChecklist(_ kinds: [ProofArtifact.Kind]) -> String {
        let order: [ProofArtifact.Kind] = [.appAttest, .nfcZk, .liveness, .antiSpoof, .faceMatch]
        let set = Set(kinds)
        return order.map { set.contains($0) ? "\u{2713} \($0.rawValue)" : "\u{00B7} \($0.rawValue)" }
            .joined(separator: "  ")
    }

    @ViewBuilder
    private var attestationRow: some View {
        HStack(spacing: 8) {
            Image(systemName: attestationIcon)
                .font(.caption)
                .foregroundStyle(attestationColor)
            Text(attestationLabel)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private var attestationIcon: String {
        switch attestation.state {
        case .idle, .attesting: return "hourglass"
        case .unsupported: return "iphone.slash"
        case .alreadyAttested, .attested: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .unattested: return "exclamationmark.shield.fill"
        }
    }

    private var attestationColor: Color {
        switch attestation.state {
        case .attested, .alreadyAttested: return Theme.brandGreen
        case .failed: return .orange
        case .unattested: return .yellow
        default: return Theme.muted
        }
    }

    private var attestationLabel: String {
        switch attestation.state {
        case .idle: return "App Attest — queued"
        case .unsupported: return "App Attest — simulator (debug provider)"
        case .attesting: return "App Attest — attesting…"
        case .alreadyAttested: return "App Attest — device attested"
        case .attested: return "App Attest — device attested"
        case .failed(let msg): return "App Attest — failed: \(msg)"
        case .unattested(let reason):
            switch reason {
            case .userSkipped: return "App Attest — skipped (unattested mode)"
            case .deviceUnsupported: return "App Attest — unavailable (unattested mode)"
            }
        }
    }

    @ViewBuilder
    private var moproRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: MoproSmokeBridge.isLinked ? "checkmark.seal.fill" : "hammer")
                    .font(.caption)
                    .foregroundStyle(MoproSmokeBridge.isLinked ? Theme.brandGreen : Theme.muted)
                Text(MoproSmokeBridge.hello())
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(3)
            }
            HStack(spacing: 8) {
                Image(systemName: proofIcon)
                    .font(.caption)
                    .foregroundStyle(proofColor)
                Text(proofLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
        }
    }

    private var proofIcon: String {
        switch proofSmoke {
        case .ok: return "checkmark.seal.fill"
        case .skipped: return "hourglass"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var proofColor: Color {
        switch proofSmoke {
        case .ok: return Theme.brandGreen
        case .failed: return .orange
        case .skipped: return Theme.muted
        }
    }

    private var proofLabel: String {
        switch proofSmoke {
        case .ok(let publicInputs):
            return "multiplier2: ok (\(publicInputs.count))"
        case .skipped:
            return "multiplier2: awaiting linked xcframework"
        case .failed(let msg):
            return "multiplier2: failed — \(msg)"
        }
    }

    @ViewBuilder
    private var pairingRow: some View {
        switch pairing.state {
        case .idle, .failed:
            Button {
                isShowingQRScanner = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Pair desktop")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(Theme.brandGreen)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.brandGreen.opacity(0.4)))
            }
            .sheet(isPresented: $isShowingQRScanner) {
                QRScannerView(
                    onScanned: { code in
                        isShowingQRScanner = false
                        pairing.claim(scannedPayload: code)
                    },
                    onCancel: { isShowingQRScanner = false }
                )
            }
        case .claiming:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Theme.muted)
                Text("Pairing desktop…")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        case .paired:
            HStack(spacing: 8) {
                Image(systemName: "desktopcomputer")
                    .font(.caption)
                    .foregroundStyle(Theme.brandGreen)
                Text("Desktop paired")
                    .font(.caption)
                    .foregroundStyle(Theme.brandGreen)
                Spacer()
                Button("Disconnect") { pairing.disconnect() }
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        case .releasing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Theme.muted)
                Text("Disconnecting desktop…")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        case .needsFreshAuth(let pending):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Sign in to confirm")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Spacer()
                }
                Text(staleAuthCopy(for: pending))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Button {
                    pairing.clearStaleAuthGate()
                    Task { try? await AuthService.shared.signOut() }
                } label: {
                    Text("Sign out & sign back in")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.brandGreen)
                        .cornerRadius(8)
                }
            }
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4)))
        }
    }

    private func staleAuthCopy(for pending: PairingCoordinator.PendingAction) -> String {
        switch pending {
        case .claim:
            return "For safety, sign back in before pairing a new desktop. Email-link sign-in confirms it's really you, not someone with a stolen phone."
        case .disconnect:
            return "For safety, sign back in before disconnecting the paired desktop. Email-link sign-in confirms it's really you, not someone with a stolen phone."
        }
    }
}
