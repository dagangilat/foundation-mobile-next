import SwiftUI

/// The sheet behind Home's bell: the app's own notifications, newest first.
///
/// Opening it marks everything read (the bell's red dot goes), while the
/// entries that were unread when it opened keep their dot for this viewing.
/// A failed verification entry offers "Try again" (the same retry as Home's
/// card) and "Share app log" (the app's own log file, as in Profile).
struct AppNotificationsSheet: View {
    @ObservedObject private var store = AppNotificationStore.shared

    /// "Try again" on a failed verification entry. Home closes this sheet and
    /// then runs the retry.
    let onRetry: (AppNotification.Retry) -> Void
    let onDone: () -> Void

    /// Unread as of opening, so the dots stay while the person reads.
    @State private var unreadAtOpen: Set<UUID>

    init(onRetry: @escaping (AppNotification.Retry) -> Void, onDone: @escaping () -> Void) {
        self.onRetry = onRetry
        self.onDone = onDone
        _unreadAtOpen = State(initialValue: Set(
            AppNotificationStore.shared.entries.filter { !$0.isRead }.map(\.id)
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Notifications")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(FoundationTheme.text)
                Spacer()
                Button("Done", action: onDone)
                    .buttonStyle(FoundationTextButtonStyle())
            }
            .padding(.top, 20)

            if store.entries.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 {
                                Rectangle()
                                    .fill(FoundationTheme.border)
                                    .frame(height: 1)
                                    .padding(.vertical, 16)
                            }
                            AppNotificationRow(
                                entry: entry,
                                isUnread: unreadAtOpen.contains(entry.id),
                                onRetry: onRetry
                            )
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .padding(.horizontal, FoundationTheme.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FoundationTheme.surface.ignoresSafeArea())
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
        .onAppear { store.markAllRead() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell")
                .font(.system(size: 28))
                .foregroundColor(FoundationTheme.muted)
            Text("Nothing here yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(FoundationTheme.text)
            Text("Updates about your verification show up here.")
                .font(.system(size: 15))
                .foregroundColor(FoundationTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }
}

private struct AppNotificationRow: View {
    let entry: AppNotification
    let isUnread: Bool
    let onRetry: (AppNotification.Retry) -> Void

    private var isError: Bool { entry.kind == .error }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isError ? FoundationTheme.dangerTint : FoundationTheme.accentTint)
                Image(systemName: isError ? "exclamationmark.circle" : "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isError ? FoundationTheme.dangerIcon : FoundationTheme.accent)
            }
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: entry.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(FoundationTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Text(verbatim: timeText)
                        .font(.system(size: 13))
                        .foregroundColor(FoundationTheme.muted)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                Text(verbatim: entry.message)
                    .font(.system(size: 14))
                    .foregroundColor(FoundationTheme.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let retry = entry.retry, isError {
                    HStack(spacing: 10) {
                        Button("Try again") { onRetry(retry) }
                            .buttonStyle(EntryButtonStyle(isPrimary: true))
                        // The app's own log file: send it by any app (Mail,
                        // Messages, AirDrop, Files) without a mail account.
                        ShareLink(item: AppLogExport(), preview: SharePreview("Foundation app log")) {
                            Text("Share app log")
                        }
                        .buttonStyle(EntryButtonStyle(isPrimary: false))
                    }
                    .padding(.top, 4)
                }
            }

            // Unread error dot; a same-width spacer keeps rows aligned.
            Circle()
                .fill(isUnread && isError ? FoundationTheme.alertDot : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.top, 7)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }

    /// "2:18 PM" today, with the date before that.
    private var timeText: String {
        if Calendar.current.isDateInToday(entry.date) {
            return entry.date.formatted(date: .omitted, time: .shortened)
        }
        return entry.date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}

/// The two small buttons on a failed verification entry (38pt high).
private struct EntryButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(isPrimary ? FoundationTheme.onAccent : FoundationTheme.accent)
            .padding(.horizontal, isPrimary ? 16 : 14)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: FoundationTheme.buttonRadius, style: .continuous)
                    .fill(isPrimary ? FoundationTheme.accent : FoundationTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FoundationTheme.buttonRadius, style: .continuous)
                    .stroke(isPrimary ? Color.clear : FoundationTheme.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .contentShape(Rectangle())
    }
}

#Preview {
    AppNotificationsSheet(onRetry: { _ in }, onDone: {})
}
