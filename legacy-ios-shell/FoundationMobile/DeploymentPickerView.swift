import SwiftUI

struct DeploymentPickerView: View {
    @ObservedObject private var service = DeploymentService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                List {
                    Section {
                        ForEach(service.all) { dep in
                            DeploymentRow(
                                deployment: dep,
                                isSelected: dep.id == service.current.id,
                                isAvailable: service.isAvailable(dep)
                            ) {
                                service.select(dep)
                                dismiss()
                            }
                        }
                    } footer: {
                        Text("Changing deployment signs you out and reconnects to a different Foundation instance. Add a GoogleService-Info-<id>.plist to the Xcode target to unlock additional deployments.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 4)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Choose Deployment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.brandGreen)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct DeploymentRow: View {
    let deployment: Deployment
    let isSelected: Bool
    let isAvailable: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(deployment.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isAvailable ? Theme.text : Theme.muted)
                        Text(deployment.version)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isAvailable ? Theme.brandGreen.opacity(0.15) : Theme.surface)
                            .foregroundStyle(isAvailable ? Theme.brandGreen : Theme.muted)
                            .clipShape(Capsule())
                    }
                    Text(deployment.description)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    if !isAvailable {
                        Text("Add \(deployment.plist).plist to Xcode to enable")
                            .font(.caption2)
                            .foregroundStyle(.orange.opacity(0.8))
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.brandGreen)
                        .font(.system(size: 18))
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(!isAvailable)
        .listRowBackground(Theme.surface)
    }
}
