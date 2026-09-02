import SwiftUI

// Sub-project 1 (2026-06-30) — lets the user choose which document they're
// verifying with before MRZScanView opens. Default screen offers the
// device-region match (if the registry has one) + generic Passport;
// "Other document" opens a live search scoped to whatever the active
// build profile can actually reach its required trust tier with (see
// DocumentProfile.available(for:)).

struct DocumentPickerView: View {
    let buildProfile: AppConfig.Profile
    let onSelected: (DocumentProfile) -> Void
    let onCancel: () -> Void

    @State private var mode: Mode = .defaultScreen
    @State private var searchQuery: String = ""

    enum Mode { case defaultScreen, search }

    private var available: [DocumentProfile] {
        DocumentProfile.available(for: buildProfile)
    }

    private var regionMatch: DocumentProfile? {
        guard let match = DocumentProfile.regionMatch(regionCode: Locale.current.region?.identifier),
              available.contains(match) else { return nil }
        return match
    }

    private var searchResults: [DocumentProfile] {
        DocumentPickerSearch.filter(available, query: searchQuery)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                switch mode {
                case .defaultScreen: defaultView
                case .search: searchView
                }
            }
            .navigationTitle("Choose your document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(Theme.brandGreen)
                }
            }
        }
    }

    private var defaultView: some View {
        VStack(spacing: 16) {
            if let regionMatch {
                documentRow(regionMatch)
            }
            documentRow(.passport)
            Button("Other document") { mode = .search }
                .font(.callout)
                .foregroundStyle(Theme.brandGreen)
                .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var searchView: some View {
        VStack(spacing: 12) {
            TextField("Search country or document", text: $searchQuery)
                .padding(10)
                .background(Theme.surface)
                .cornerRadius(8)
                .foregroundStyle(Theme.text)
                .autocorrectionDisabled()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(searchResults) { profile in
                        documentRow(profile)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func documentRow(_ profile: DocumentProfile) -> some View {
        Button {
            onSelected(profile)
        } label: {
            HStack {
                Text(profile.displayName)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.surface)
            .cornerRadius(12)
        }
    }
}

enum DocumentPickerSearch {
    static func filter(_ profiles: [DocumentProfile], query: String) -> [DocumentProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return profiles }
        return profiles.filter { $0.displayName.localizedCaseInsensitiveContains(trimmed) }
    }
}
