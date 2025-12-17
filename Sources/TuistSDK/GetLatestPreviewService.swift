import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

protocol GetLatestPreviewServicing: Sendable {
    func getLatestPreview(
        binaryId: String,
        buildVersion: String,
        fullHandle: String
    ) async throws -> Components.Schemas.Preview?
}

enum GetLatestPreviewServiceError: LocalizedError {
    case unknownError(Int)
    case forbidden(String)
    case unauthorized(String)
    case invalidFullHandle(String)

    var errorDescription: String? {
        switch self {
        case let .unknownError(statusCode):
            return "The latest preview could not be fetched due to an unknown response: \(statusCode)."
        case let .forbidden(message), let .unauthorized(message):
            return message
        case let .invalidFullHandle(fullHandle):
            return "Invalid full handle format: \(fullHandle). Expected format: account-handle/project-handle."
        }
    }
}

struct GetLatestPreviewService: GetLatestPreviewServicing {
    private let serverURL: URL
    private let apiKey: String

    init(serverURL: URL, apiKey: String) {
        self.serverURL = serverURL
        self.apiKey = apiKey
    }

    func getLatestPreview(
        binaryId: String,
        buildVersion: String,
        fullHandle: String
    ) async throws -> Components.Schemas.Preview? {
        let components = fullHandle.components(separatedBy: "/")
        guard components.count == 2 else {
            throw GetLatestPreviewServiceError.invalidFullHandle(fullHandle)
        }
        let accountHandle = components[0]
        let projectHandle = components[1]

        let client = Client(
            serverURL: serverURL,
            transport: URLSessionTransport(),
            middlewares: [AuthenticationMiddleware(apiKey: apiKey)]
        )

        let response = try await client.getLatestPreview(
            .init(
                path: .init(
                    account_handle: accountHandle,
                    project_handle: projectHandle
                ),
                query: .init(binary_id: binaryId, build_version: buildVersion)
            )
        )

        switch response {
        case let .ok(okResponse):
            switch okResponse.body {
            case let .json(latestPreviewResponse):
                return latestPreviewResponse.preview
            }
        case let .undocumented(statusCode: statusCode, _):
            throw GetLatestPreviewServiceError.unknownError(statusCode)
        case let .forbidden(forbiddenResponse):
            switch forbiddenResponse.body {
            case let .json(error):
                throw GetLatestPreviewServiceError.forbidden(error.message)
            }
        case let .unauthorized(unauthorizedResponse):
            switch unauthorizedResponse.body {
            case let .json(error):
                throw GetLatestPreviewServiceError.unauthorized(error.message)
            }
        }
    }
}
