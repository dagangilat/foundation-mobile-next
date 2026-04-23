import Foundation
import FirebaseFirestore

@MainActor
final class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    struct UserDoc: Equatable, Sendable {
        let ring: Int?
        let inviteStatus: String?
    }

    @Published private(set) var userDoc: UserDoc?

    private var registration: ListenerRegistration?

    func observeUser(uid: String) {
        registration?.remove()
        let db = Firestore.firestore()
        registration = db.collection("users").document(uid).addSnapshotListener { [weak self] snap, _ in
            Task { @MainActor in
                guard let self, let data = snap?.data() else {
                    self?.userDoc = nil
                    return
                }
                let ring = (data["ring"] as? Int) ?? (data["ring"] as? NSNumber)?.intValue
                self.userDoc = UserDoc(
                    ring: ring,
                    inviteStatus: data["inviteStatus"] as? String
                )
            }
        }
    }

    func stopObserving() {
        registration?.remove()
        registration = nil
        userDoc = nil
    }
}
