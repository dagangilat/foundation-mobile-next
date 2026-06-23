import Foundation
import FirebaseFirestore

// Combines the two independent server signals that each mark a user as
// humanity-verified. CRITICAL: both must be able to flip back to false so an
// admin "reset humanity verification" — which sets users/{uid}.humanityVerified
// =false AND deletes the anchored identity_commitments doc — actually demotes
// the badges instead of latching green. The earlier promote-only design only
// ever set the flag true and ignored a server false, so a reset left the app
// "all green" until a delete+reinstall.
struct HumanityVerificationState: Equatable {
    // users/{uid}.humanityVerified — fast-path, paints green on cold launch
    // the moment the user-doc listener fires.
    var userDocVerified = false
    // Any identity_commitments/{uid}/commitments doc at status="anchored" —
    // the authoritative source.
    var commitmentAnchored = false

    var isVerified: Bool { userDocVerified || commitmentAnchored }
}

@MainActor
final class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    struct UserDoc: Equatable, Sendable {
        let ring: Int?
        let inviteStatus: String?
    }

    @Published private(set) var userDoc: UserDoc?

    // True once EITHER the user-doc fast-path flag is set OR an
    // identity_commitments doc has reached status="anchored". Drives
    // HomeView's swap to WebHomeView so the Verify-humanity CTA +
    // technical readouts disappear after a successful registration.
    // Persists across app launches — unlike CaptureCoordinator.anchorStatus,
    // which is in-memory only. Derived from `verificationState` so a server
    // reset of either signal demotes it.
    @Published private(set) var humanityVerified: Bool = false

    private var verificationState = HumanityVerificationState() {
        didSet { humanityVerified = verificationState.isVerified }
    }

    private var registration: ListenerRegistration?
    private var humanityRegistration: ListenerRegistration?

    func observeUser(uid: String) {
        registration?.remove()
        let db = Firestore.firestore()
        registration = db.collection("users").document(uid).addSnapshotListener { [weak self] snap, _ in
            Task { @MainActor in
                guard let self else { return }
                guard let data = snap?.data() else {
                    // User doc gone (e.g. wiped) — drop the fast-path signal
                    // too, don't leave it latched true.
                    self.userDoc = nil
                    self.verificationState.userDocVerified = false
                    return
                }
                let ring = (data["ring"] as? Int) ?? (data["ring"] as? NSNumber)?.intValue
                self.userDoc = UserDoc(
                    ring: ring,
                    inviteStatus: data["inviteStatus"] as? String
                )
                // Fast-path hydrate: anchorIdentityCommitmentTask stamps
                // users/{uid}.humanityVerified=true atomically with the
                // commitments doc flip, so the verification badges paint
                // green on cold launch the moment this listener fires,
                // without waiting for the identity_commitments query below
                // to round-trip. Honour false too — an admin reset writes
                // humanityVerified=false here, and for manually-approved
                // users (no anchored commitment) this is the ONLY signal
                // that demotes them.
                self.verificationState.userDocVerified = (data["humanityVerified"] as? Bool) ?? false
            }
        }

        humanityRegistration?.remove()
        // limit:1 — we only need yes/no. Server marks the doc
        // status="anchored" inside anchorIdentityCommitmentTask once
        // the Solana tx lands.
        //
        // Path matches server-side anchorCommitment + handler:
        //   identity_commitments/{uid}/commitments/{hashHex}
        // Earlier this listened at users/{uid}/identity_commitments
        // (drift from a pre-Phase-2 layout) and silently never matched.
        // A future "passport expired" filter will layer on top so an
        // old anchored commitment doesn't keep the user out of the
        // verify funnel forever.
        humanityRegistration = db.collection("identity_commitments")
            .document(uid)
            .collection("commitments")
            .whereField("status", isEqualTo: "anchored")
            .limit(to: 1)
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.verificationState.commitmentAnchored = !(snap?.documents.isEmpty ?? true)
                }
            }
    }

    func stopObserving() {
        registration?.remove()
        registration = nil
        humanityRegistration?.remove()
        humanityRegistration = nil
        userDoc = nil
        verificationState = HumanityVerificationState()
    }
}
