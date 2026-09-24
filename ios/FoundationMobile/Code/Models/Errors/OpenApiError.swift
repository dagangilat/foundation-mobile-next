import Alamofire
import Foundation

struct OpenApiErrorMeta: Codable {
    let error: String
    let field: String
}

struct OpenApiError: Codable {
    let title: String
    let status: String
    let meta: OpenApiErrorMeta?
}

typealias OpenApiErrors = [OpenApiError]

struct OpenApiErrorResponse: Codable {
    let errors: OpenApiErrors
}

extension OpenApiErrors {
    var localizedDescription: String {
        return self.map(
            { error in
                var errorMessage = error.title
                if let meta = error.meta {
                    errorMessage += ": \(meta.field): \(meta.error)"
                }

                return errorMessage
            }
        ).joined(separator: ", ")
    }
}

extension OpenApiError {
    static func catchInstance(
        _ request: URLRequest?,
        _ response: HTTPURLResponse,
        _ data: Data?
    ) -> Result<Void, Error> {
        switch response.statusCode {
        case 200...299:
            return .success(())
        case 500...599:
            // Keep what the server said (e.g. the relayer's revert reason),
            // trimmed; an empty body is still reported as "service down".
            let body = data.flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if body.isEmpty { return .failure(Errors.serviceDown(request?.url)) }

            return .failure(Errors.serviceError(request?.url, response.statusCode, String(body.prefix(500))))
        case 400...499:
            guard let data else { return .failure(Errors.unknownServiceError) }

            let decoder = JSONDecoder()
            let response = try? decoder.decode(OpenApiErrorResponse.self, from: data)
            guard let response else { return .failure(Errors.invalidResponseBody) }

            return .failure(Errors.openAPIErrors(response.errors))
        default:
            return .failure(Errors.invalidHTTPStatusCode(response.statusCode))
        }
    }
}
