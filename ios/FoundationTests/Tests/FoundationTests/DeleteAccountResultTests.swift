import XCTest
@testable import FoundationMobile

/// `deleteMyAccount` performs an irreversible server-side hard delete, so by
/// the time this struct is built the account is already gone. That makes the
/// decode's *tolerance* the property worth testing: a client that threw on an
/// unexpected field would report a successful erasure as a failure and leave
/// the member signed in to an account that no longer exists.
///
/// `FunctionsService.deleteMyAccount()` itself is not exercised here - it needs
/// a live Firebase Functions client and a real signed-in session, and the one
/// thing that would make such a test meaningful is invoking a callable that
/// cannot be undone. What IS covered is the whole of the decoding it does.
final class DeleteAccountResultTests: XCTestCase {
    private func decode(_ json: String) throws -> DeleteAccountResult {
        try JSONDecoder().decode(DeleteAccountResult.self, from: Data(json.utf8))
    }

    /// The real reply, as `@plantagoai/auth`'s `deleteAccount()` builds it -
    /// `collections` and `external` included, which this client deliberately
    /// does not model.
    func testDecodesTheRealDeletionResultShape() throws {
        let result = try decode("""
        {
          "userId": "uid-abc",
          "deletedDocs": 12,
          "anonymizedDocs": 3,
          "retainedDocs": 1,
          "authDeleted": true,
          "collections": {
            "voters": { "mode": "delete", "count": 1 },
            "votes": { "mode": "anonymize", "count": 3 }
          },
          "external": ["braintree"],
          "completedAt": "2026-09-03T10:00:00.000Z",
          "dryRun": false
        }
        """)

        XCTAssertEqual(result.userId, "uid-abc")
        XCTAssertEqual(result.deletedDocs, 12)
        XCTAssertEqual(result.anonymizedDocs, 3)
        XCTAssertEqual(result.retainedDocs, 1)
        XCTAssertEqual(result.authDeleted, true)
        XCTAssertEqual(result.completedAt, "2026-09-03T10:00:00.000Z")
        XCTAssertEqual(result.dryRun, false)
    }

    /// Server-side shape drift must not be able to turn a completed deletion
    /// into a client-side failure. An empty object is the extreme case of every
    /// field this client knows about having gone away.
    func testAnEmptyObjectStillDecodes() throws {
        let result = try decode("{}")

        XCTAssertNil(result.userId)
        XCTAssertNil(result.deletedDocs)
        XCTAssertNil(result.authDeleted)
        XCTAssertNil(result.dryRun)
    }

    /// Unknown fields are ignored rather than rejected - the reply gaining a
    /// key is the likeliest drift of all.
    func testUnknownFieldsAreIgnored() throws {
        let result = try decode("""
        { "userId": "uid-abc", "deletedDocs": 4, "somethingAddedLater": { "nested": true } }
        """)

        XCTAssertEqual(result.userId, "uid-abc")
        XCTAssertEqual(result.deletedDocs, 4)
    }

    /// `authDeleted: false` is NOT a failure signal and nothing may gate on it:
    /// `deleteAccount()` swallows "user not found" from `auth.deleteUser` and
    /// reports `false`, which is exactly what re-running against an
    /// already-erased account produces.
    func testAuthDeletedFalseIsCarriedAsInformationOnly() throws {
        let result = try decode("""
        { "userId": "uid-abc", "deletedDocs": 0, "authDeleted": false, "dryRun": false }
        """)

        XCTAssertEqual(result.authDeleted, false)
        XCTAssertEqual(
            result.dryRun, false,
            "dryRun is the only field that means 'nothing was deleted' - authDeleted is not"
        )
    }
}
