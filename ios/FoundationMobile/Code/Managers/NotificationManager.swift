import CoreData
import FirebaseCore
import FirebaseMessaging
import Foundation
import SwiftUI
import UserNotifications

// This fork's own App Group, shared with NotificationBackgroundProcessor. Must
// match com.apple.security.application-groups in both targets' entitlements.
// Rarimo's group could not be kept: App Group ids belong to one team, so
// device and archive signing under ours failed with it.
class NotificationManager: ObservableObject {
    static let userDefaults = UserDefaults(suiteName: "group.com.foundationnext.mobile")!
    
    static let shared = NotificationManager()
    
    static let UNREAD_NOTIFICATIONS_COUNTER_KEY = "unread_notifications_counter"
    
    let pushNotificationContainer = NSPersistentContainer(name: "PushNotification")
    
    @Published var unreadNotificationsCounter: Int = NotificationManager.userDefaults.integer(forKey: NotificationManager.UNREAD_NOTIFICATIONS_COUNTER_KEY) {
        didSet {
            UNUserNotificationCenter.current().setBadgeCount(unreadNotificationsCounter)
            NotificationManager.userDefaults.set(unreadNotificationsCounter, forKey: NotificationManager.UNREAD_NOTIFICATIONS_COUNTER_KEY)
        }
    }
    
    init() {
        let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.foundationnext.mobile")!
            .appendingPathComponent("PushNotification.sqlite")
        
        pushNotificationContainer.persistentStoreDescriptions = [
            NSPersistentStoreDescription(url: url)
        ]
        
        pushNotificationContainer.loadPersistentStores { _, error in
            if let error {
                LoggerUtil.common.error("Error loading Core Data: \(error, privacy: .public)")
            }
        }
    }
    
    func request() async throws {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        
        let globalNotificationTopic = ConfigManager.shared.notifications.generalTopic
        
        // Firebase recommends to run this on the main thread
        DispatchQueue.main.async {
            Messaging.messaging().subscribe(toTopic: globalNotificationTopic) { error in
                if let error {
                    LoggerUtil.common.error("Error subscribing to topic: \(error, privacy: .public)")
                }
            }
        }
    }
    
    func subscribe(toTopic: String) async throws {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        
        // Firebase recommends to run this on the main thread
        DispatchQueue.main.async {
            Messaging.messaging().subscribe(toTopic: toTopic) { error in
                if let error { LoggerUtil.common.error("Error subscribing to topic: \(error, privacy: .public)") }
            }
        }
    }
    
    func unsubscribe(fromTopic: String) async throws {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        
        // Firebase recommends to run this on the main thread
        DispatchQueue.main.async {
            Messaging.messaging().unsubscribe(fromTopic: fromTopic) { error in
                if let error { LoggerUtil.common.error("Error unsubscribing from topic: \(error, privacy: .public)") }
            }
        }
    }
    
    func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings()
        
        switch status.authorizationStatus {
        case .authorized, .ephemeral, .provisional:
            return true
        default:
            return false
        }
    }
    
    func saveNotification(_ pushNotificationRaw: PushNotificationRaw) throws {
        let viewContext = pushNotificationContainer.viewContext
        
        let pushNotification = PushNotification(context: viewContext)
        pushNotification.id = UUID()
        pushNotification.title = pushNotificationRaw.aps.alert.title
        pushNotification.body = pushNotificationRaw.aps.alert.body
        pushNotification.receivedAt = Date()
        pushNotification.isRead = false
        pushNotification.type = pushNotificationRaw.type?.rawValue
        pushNotification.content = pushNotificationRaw.content
        
        unreadNotificationsCounter += 1
        
        try viewContext.save()
        
        LoggerUtil.common.info("Notification saved")
    }
    
    func eraceUnreadNotificationsCounter() {
        unreadNotificationsCounter = 0
    }
    
    func reset() {
        let viewContext = pushNotificationContainer.viewContext
        
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PushNotification.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(deleteRequest)
            unreadNotificationsCounter = 0
        } catch {
            LoggerUtil.common.error("Error deleting all notifications: \(error, privacy: .public)")
        }
    }
}
