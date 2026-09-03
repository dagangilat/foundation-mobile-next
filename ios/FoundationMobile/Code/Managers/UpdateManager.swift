import Alamofire
import Foundation

class UpdateManager: ObservableObject {
    @Published var isDeprecated: Optional<Bool> = nil
    /// Dormant since Task B5: the maintenance flag was served by the upstream
    /// points service, which is no longer called. `MaintenanceView` stays wired
    /// up so a Foundation-owned source can set this later.
    @Published var isMaintenance: Bool = false
    
    static let shared = UpdateManager()
    
    func isUpdateAvailable() async throws -> Bool {
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return false
        }
        
        guard
            let info = Bundle.main.infoDictionary,
            let currentVersion = info["CFBundleShortVersionString"] as? String,
            let identifier = info["CFBundleIdentifier"] as? String
        else {
            throw UpdateManagerError.invalidBundleInfo
        }
        
        let response = try await AF.request("https://itunes.apple.com/lookup?bundleId=\(identifier)")
            .serializingDecodable(ITunesLookupResponse.self)
            .result
            .get()
        
        guard let firstResult = response.results.first else {
            throw UpdateManagerError.emptyResponse
        }
        
        return firstResult.version.compare(currentVersion, options: .numeric) == .orderedDescending
    }
    
    @MainActor
    func checkForUpdate() async {
        do {
            let isDeprecated = try await isUpdateAvailable()
            
            self.isDeprecated = isDeprecated
        } catch {
            self.isDeprecated = false
            
            LoggerUtil.common.error("Failed to check for update: \(error, privacy: .public)")
        }
    }
}

struct ITunesLookupResponse: Codable {
    let results: [ITunesLookupResponseResult]
}

struct ITunesLookupResponseResult: Codable {
    let version: String
}

enum UpdateManagerError: Error {
    case invalidBundleInfo
    case emptyResponse
    
    var localizedDescription: String {
        switch self {
        case .invalidBundleInfo:
            return "Invalid bundle info"
        case .emptyResponse:
            return "Response is empty"
        }
    }
}
