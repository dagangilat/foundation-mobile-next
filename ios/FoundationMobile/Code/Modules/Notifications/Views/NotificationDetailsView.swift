import SwiftUI

struct NotificationDetailsView: View {
    let notification: PushNotification
    
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            AppIconButton(icon: .closeFill, action: onClose)
                .padding([.top, .trailing], 20)
                .frame(maxWidth: .infinity, alignment: .trailing)
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(notification.title ?? "")
                        .subtitle4()
                        .foregroundStyle(.textPrimary)
                    Text(notification.receivedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")
                        .caption2()
                        .foregroundStyle(.textSecondary)
                }
                ScrollView {
                    Text(notification.body ?? "")
                        .body4()
                        .foregroundStyle(.textSecondary)
                        .align()
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
    }
}

#Preview {
    let pushNotification = PushNotification(
        context: NotificationManager.shared.pushNotificationContainer.viewContext
    )
    pushNotification.id = UUID()
    pushNotification.title = "Other title"
    pushNotification.body = "It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout. The point of using Lorem Ipsum is that it has a more-or-less normal distribution of letters, as opposed to using 'Content here, content here', making it look like readable English. Many desktop publishing packages and web page editors now use Lorem Ipsum as their default model text"
    pushNotification.receivedAt = Date()
    pushNotification.isRead = false
    
    return ZStack {}
        .dynamicSheet(isPresented: .constant(true), fullScreen: true) {
            NotificationDetailsView(notification: pushNotification) {}
        }
}
