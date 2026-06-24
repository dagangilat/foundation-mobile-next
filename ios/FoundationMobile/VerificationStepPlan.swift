import Foundation

struct VerificationStep: Equatable {
    let title: String
    let subtitle: String
}

// Profile-derived onboarding step list for the overview checklist + explainer
// rhythm. A chipless edition never promises a chip read; a device-only edition
// is face-check only. Document noun is injected from the active profile.
enum VerificationStepPlan {
    static func steps(for profile: AppConfig.Profile) -> [VerificationStep] {
        var steps: [VerificationStep] = []
        // Order mirrors the runtime capture sequence the user actually
        // experiences — face first, then document, chip, anti-spoof, seal —
        // so the overview checklist can't contradict the live flow.
        // (Phase 0, the open-app biometric gate, is excluded by design.)
        if profile.requires(.liveness) {
            steps.append(VerificationStep(title: "Quick face check",
                                          subtitle: "A short look at the camera"))
        }
        // A document scan yields the MRZ key for the chip read and the
        // document-photo face match, so it precedes both.
        if profile.requires(.nfcZk) || profile.faceMatchSource == .documentPhoto {
            steps.append(VerificationStep(title: "Scan your \(profile.documentNoun)",
                                          subtitle: "Photo page, laid flat"))
        }
        if profile.requires(.nfcZk) {
            steps.append(VerificationStep(title: "Read the chip",
                                          subtitle: "Hold the back of your phone"))
        }
        // Anti-spoof runs automatically on the face frames already captured —
        // listed so the user sees it happen, no action required.
        if profile.requires(.antiSpoof) {
            steps.append(VerificationStep(title: "Anti-spoof check",
                                          subtitle: "Automatic — confirms a live person"))
        }
        // The final Secure-Enclave biometric seal closes every edition.
        steps.append(VerificationStep(title: "Apple Biometric Seal",
                                      subtitle: "Face ID confirms it's you"))
        return steps
    }
}
