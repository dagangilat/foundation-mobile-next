import Foundation

// Read-only devnet RPC. Mobile never signs or submits on-chain transactions —
// writes go through the `anchorCommitment` Cloud Functions callable. This
// actor is only for surfacing commitment state in the UI.
actor SolanaRPC {
    static let devnet = SolanaRPC(endpoint: URL(string: "https://api.devnet.solana.com")!)

    private let endpoint: URL
    private let session: URLSession

    init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    struct AccountInfo: Decodable, Sendable {
        struct Value: Decodable, Sendable {
            let lamports: UInt64
            let owner: String
            let executable: Bool
        }
        let value: Value?
    }

    func getAccountInfo(pubkey: String) async throws -> AccountInfo {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getAccountInfo",
            "params": [pubkey, ["encoding": "base64"]],
        ]
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: req)
        struct Envelope: Decodable { let result: AccountInfo }
        return try JSONDecoder().decode(Envelope.self, from: data).result
    }
}
