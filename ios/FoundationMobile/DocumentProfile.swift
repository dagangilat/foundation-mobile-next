import Foundation

// Sub-project 1 (2026-06-30) — registry of ICAO-aligned biometric NFC
// documents the app can read, beyond the original passport-only pipeline.
// Static data, no remote config in v1. See
// docs/superpowers/specs/2026-06-30-nfc-document-registry-design.md.

struct DocumentProfile: Identifiable, Equatable {
    enum DocumentType: Equatable {
        case passport
        case nationalId
    }

    enum MRZFormat: Equatable {
        case td1   // 3 lines x 30 chars — national ID cards
        case td3   // 2 lines x 44 chars — passports
    }

    let id: String                  // e.g. "passport", "isr-id"
    let countryCode: String?        // ISO 3166-1 alpha-2; nil for generic Passport
    let displayName: String         // "Teudat Zehut", "Passport"
    let documentType: DocumentType
    let mrzFormat: MRZFormat
    // Face photo (DG2) retrievable via BAC/PACE alone, no EAC. Assumed true
    // for every seeded national-ID entry pending hardware verification —
    // see the spec's Testing section, Tier 3. Not yet verified against any
    // real document except the existing passport flow.
    let dg2Accessible: Bool

    static let passport = DocumentProfile(
        id: "passport", countryCode: nil, displayName: "Passport",
        documentType: .passport, mrzFormat: .td3, dg2Accessible: true
    )

    static let all: [DocumentProfile] = [
        .passport,
        DocumentProfile(id: "isr-id", countryCode: "IL", displayName: "Teudat Zehut",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "deu-id", countryCode: "DE", displayName: "Personalausweis",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "fra-id", countryCode: "FR", displayName: "Carte nationale d'identité",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "prt-id", countryCode: "PT", displayName: "Cartão de Cidadão",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "ita-id", countryCode: "IT", displayName: "Carta d'Identità Elettronica",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "esp-id", countryCode: "ES", displayName: "DNI electrónico",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "jpn-id", countryCode: "JP", displayName: "My Number Card",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
        DocumentProfile(id: "bra-id", countryCode: "BR", displayName: "Carteira de Identidade Nacional",
                         documentType: .nationalId, mrzFormat: .td1, dg2Accessible: true),
    ]

    // Documents the active build profile can reach its required trust tier
    // with. hisec-global (faceMatchSource == .dg2) only offers documents
    // whose chip exposes DG2 via BAC/PACE; standardsec/lowsec-attest don't
    // depend on DG2 for face match, so every registry document is offered.
    static func available(for profile: AppConfig.Profile) -> [DocumentProfile] {
        guard profile.faceMatchSource == .dg2 else { return all }
        return all.filter(\.dg2Accessible)
    }

    // Best-guess national-ID entry for the device's region, if the registry
    // has one. Used by DocumentPickerView's default screen.
    static func regionMatch(regionCode: String?) -> DocumentProfile? {
        guard let regionCode else { return nil }
        return all.first { $0.countryCode == regionCode }
    }
}
