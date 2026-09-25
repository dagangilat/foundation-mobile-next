import Foundation
import CloudKit

// This fork's own iCloud container. Must match
// com.apple.developer.icloud-container-identifiers in FoundationMobile.entitlements;
// Xcode's automatic signing registers it under team F9F26FQW95 on first
// device build. Rarimo's container could not be kept: container ids belong to
// one team, so signing under ours failed with it.
class CloudStorage {
    static let shared = CloudStorage()

    let db = CKContainer(identifier: "iCloud.com.foundationnext.mobile").privateCloudDatabase

    func saveRecord(_ record: CKRecord) async throws {
        let _ = try await db.save(record)
    }

    func fetchRecords(_ query: CKQuery) async throws -> [CKRecord] {
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let results: [(CKRecord.ID, Result<CKRecord, Error>)]
        do {
            results = try await db.records(matching: query).matchResults
        } catch let error as CKError where error.code == .unknownItem {
            // "Did not find record type": nothing of this type was ever
            // saved in this container, which just means there are no
            // records yet. Without this, the first backup failed too,
            // since saving starts with this same query.
            return []
        }
        
        var records: [CKRecord] = []
        for (_, recordSearchResult) in results {
            switch recordSearchResult {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                throw error
            }
        }

        return records
    }

    func deleteRecord(_ id: CKRecord.ID) async throws {
        let _ = try await db.deleteRecord(withID: id)
    }

    func isICloudAvailable() async throws -> Bool {
        let accountStatus = try await CKContainer(identifier: "iCloud.com.foundationnext.mobile").accountStatus()

        return accountStatus == .available
    }
}
