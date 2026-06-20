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
        // A document scan precedes both the chip read (it yields the MRZ key)
        // and the document-photo face match.
        if profile.requires(.nfcZk) || profile.faceMatchSource == .documentPhoto {
            steps.append(VerificationStep(title: "Scan your \(profile.documentNoun)",
                                          subtitle: "Photo page, laid flat"))
        }
        if profile.requires(.nfcZk) {
            steps.append(VerificationStep(title: "Read the chip",
                                          subtitle: "Hold the back of your phone"))
        }
        if profile.requires(.liveness) {
            steps.append(VerificationStep(title: "Quick face check",
                                          subtitle: "A short look at the camera"))
        }
        return steps
    }
}
