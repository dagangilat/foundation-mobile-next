import Foundation

enum ExplainerKind: CaseIterable, Identifiable {
    case scan, chip, face
    var id: Self { self }
}

struct ExplainerStep: Equatable {
    let kind: ExplainerKind
    let title: String
    let body: String
    let cta: String
}

// Copy for the explain-before-you-do screens (design: poh-flow2 C1/C2/C3), one
// per capture stage. Document noun is injected; possessive phrasing keeps it
// grammatical for any edition.
enum ExplainerCatalog {
    static func step(_ kind: ExplainerKind, profile: AppConfig.Profile) -> ExplainerStep {
        let noun = profile.documentNoun
        switch kind {
        case .scan:
            return ExplainerStep(kind: .scan, title: "Scan your \(noun)",
                body: "Open your \(noun) to the photo page and lay it flat in good light. We'll line up the frame and capture it for you — no perfect aim needed.",
                cta: "I'm ready")
        case .chip:
            return ExplainerStep(kind: .chip, title: "Read the chip",
                body: "Hold the top back of your phone flat against your \(noun)'s photo page. Keep still until it buzzes — about 3–5 seconds.",
                cta: "I'm ready")
        case .face:
            return ExplainerStep(kind: .face, title: "Quick face check",
                body: "Center your face and follow the prompts. This confirms a live person — matched on-device, then discarded.",
                cta: "I'm ready")
        }
    }
}
