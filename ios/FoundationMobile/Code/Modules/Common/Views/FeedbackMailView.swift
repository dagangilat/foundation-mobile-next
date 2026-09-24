import MessageUI
import SwiftUI

struct FeedbackMailView: View {
    @Binding var isShowing: Bool
    @State private var feedbackAttachment = Data()

    var body: some View {
        if !feedbackAttachment.isEmpty {
            MailView(
                subject: "Feedback from: \(UIDevice.modelName)",
                attachment: feedbackAttachment,
                fileName: "logs.txt",
                isShowing: $isShowing,
                result: .constant(nil)
            )
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .controlSize(.large)
                .onAppear(perform: fetchLogsForFeedback)
        }
    }

    /// Reads this run's log off the main thread. Always produces an
    /// attachment: an empty or unreadable log used to leave the spinner up
    /// forever, since the mail view only opens once there is data.
    func fetchLogsForFeedback() {
        Task {
            let text = await Task.detached(priority: .userInitiated) { () -> String in
                do {
                    let entries = try LoggerUtil.export()
                    return entries.isEmpty
                        ? "No log entries were found for this run of the app."
                        : entries.joined(separator: "\n")
                } catch {
                    return "Couldn't read the app log: \(error)"
                }
            }.value

            await MainActor.run {
                self.feedbackAttachment = Data(text.utf8)
            }
        }
    }
}

#Preview {
    FeedbackMailView(isShowing: .constant(true))
}
