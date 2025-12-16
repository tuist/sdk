import Foundation
@testable import TuistSDK

final class MockGetLatestPreviewService: GetLatestPreviewServicing, @unchecked Sendable {
    var getLatestPreviewStub: ((String, String) async throws -> Components.Schemas.Preview?)?

    func getLatestPreview(
        binaryId: String,
        fullHandle: String
    ) async throws -> Components.Schemas.Preview? {
        try await getLatestPreviewStub?(binaryId, fullHandle)
    }
}
