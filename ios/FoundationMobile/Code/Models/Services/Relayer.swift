import Alamofire
import Foundation

class Relayer {
    let url: URL

    init(_ url: URL) {
        self.url = url
    }

    func register(
        _ calldata: Data,
        _ destination: String? = nil,
        _ noSend: Bool = false,
        meta: [String: String]? = nil
    ) async throws -> EvmTxResponse {
        var requestURL = url
        requestURL.append(path: "/integrations/registration-relayer/v1/register")

        let payload = RegisterRequest(
            data: RegisterRequestData(
                txData: "0x" + calldata.hex,
                destination: destination,
                noSend: noSend,
                meta: meta
            )
        )

        LoggerUtil.common.info("Relayer: sending \(calldata.count, privacy: .public) bytes to \(destination ?? "default", privacy: .public), selector 0x\(calldata.prefix(4).hex, privacy: .public), meta \(meta ?? [:], privacy: .public)")

        do {
            let response = try await AF.request(
                requestURL,
                method: .post,
                parameters: payload,
                encoder: JSONParameterEncoder.default
            )
            .validate(OpenApiError.catchInstance)
            .serializingDecodable(EvmTxResponse.self)
            .result
            .get()

            LoggerUtil.common.info("Relayer: accepted, tx \(response.data.attributes.txHash, privacy: .public)")
            return response
        } catch {
            // The relayer answers a transaction the chain would reject with a
            // bare 500. Running the same call read-only against the chain
            // returns the contract's own reason.
            let relayerError = PassportViewModel.describe(error)
            LoggerUtil.common.error("Relayer: rejected: \(relayerError, privacy: .public)")

            guard let destination else { throw error }

            let chainAnswer = await ContractCallCheck.run(calldata, to: destination)
            LoggerUtil.common.error("Relayer: chain check of the same call: \(chainAnswer, privacy: .public)")

            throw Errors.unknown("\(relayerError) | Chain check: \(chainAnswer)")
        }
    }

    func likenessRegistry(
        _ calldata: Data,
        _ destination: String? = nil,
        _ noSend: Bool = false,
        meta: [String: String]? = nil
    ) async throws -> EvmTxResponse {
        var requestURL = url
        requestURL.append(path: "/integrations/registration-relayer/v1/likeness-registry")

        let payload = RegisterRequest(
            data: RegisterRequestData(
                txData: "0x" + calldata.hex,
                destination: destination,
                noSend: noSend,
                meta: meta
            )
        )

        return try await AF.request(
            requestURL,
            method: .post,
            parameters: payload,
            encoder: JSONParameterEncoder.default
        )
        .validate(OpenApiError.catchInstance)
        .serializingDecodable(EvmTxResponse.self)
        .result
        .get()
    }
}

struct RegisterRequest: Encodable {
    let data: RegisterRequestData
}

struct RegisterRequestData: Encodable {
    let txData: String
    let destination: String?
    let noSend: Bool?
    let meta: [String: String]?

    enum CodingKeys: String, CodingKey {
        case txData = "tx_data"
        case destination
        case noSend = "no_send"
    }
}

/// Runs a transaction's calldata as a read-only `eth_call` against the chain
/// and reports what the contract says about it.
enum ContractCallCheck {
    static func run(_ calldata: Data, to address: String) async -> String {
        var request = URLRequest(url: ConfigManager.shared.evm.rpcURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_call",
            "params": [["to": address, "data": "0x" + calldata.hex], "latest"],
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)

            guard let reply = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return "unreadable reply from the chain"
            }

            guard let error = reply["error"] as? [String: Any] else {
                return "the call goes through on-chain, so the relayer refused it for its own reasons"
            }

            let message = error["message"] as? String ?? "reverted"
            let revertData = (error["data"] as? String)
                ?? ((error["data"] as? [String: Any])?["data"] as? String)

            guard let revertData, let decoded = decodeRevert(revertData) else { return message }

            return "\(message) (\(decoded))"
        } catch {
            return "couldn't reach the chain: \(error.localizedDescription)"
        }
    }

    /// Error(string), Panic(uint256), or the raw custom-error selector.
    static func decodeRevert(_ hex: String) -> String? {
        let bytes = bytes(fromHex: hex)
        guard bytes.count >= 4 else { return nil }

        let selector = bytes.prefix(4).map { String(format: "%02x", $0) }.joined()

        switch selector {
        case "08c379a0" where bytes.count >= 4 + 64:
            let length = bytes[(4 + 32)..<(4 + 64)].suffix(8).reduce(0) { $0 << 8 | Int($1) }
            let start = 4 + 64
            guard length >= 0, start + length <= bytes.count else { return nil }
            return "reason: " + String(decoding: bytes[start..<(start + length)], as: UTF8.self)
        case "4e487b71" where bytes.count >= 4 + 32:
            let code = bytes.suffix(32).suffix(8).reduce(0) { $0 << 8 | Int($1) }
            return String(format: "panic 0x%02x", code)
        default:
            let dataHex = bytes.map { String(format: "%02x", $0) }.joined()
            return "custom error 0x\(selector), data 0x\(dataHex.prefix(400))"
        }
    }

    private static func bytes(fromHex hex: String) -> [UInt8] {
        let digits = Array(hex.hasPrefix("0x") ? hex.dropFirst(2) : Substring(hex))
        guard digits.count % 2 == 0 else { return [] }

        var result: [UInt8] = []
        result.reserveCapacity(digits.count / 2)
        var index = 0
        while index < digits.count {
            guard let byte = UInt8(String(digits[index..<(index + 2)]), radix: 16) else { return [] }
            result.append(byte)
            index += 2
        }
        return result
    }
}
