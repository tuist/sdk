import Foundation
import Testing
@testable import TuistSDK

extension Components.Schemas.Preview {
    static func test(
        id: String = "preview-1",
        binaryIds: [String] = [],
        bundleIdentifier: String? = "com.example.app",
        displayName: String? = "My App",
        version: String? = nil,
        gitBranch: String? = nil,
        url: String = "https://example.com/preview"
    ) -> Self {
        Components.Schemas.Preview(
            builds: binaryIds.map { binaryId in
                Components.Schemas.AppBuild(
                    binary_id: binaryId,
                    id: "build-\(binaryId)",
                    supported_platforms: [.ios],
                    _type: .ipa,
                    url: "https://example.com/\(binaryId).ipa"
                )
            },
            bundle_identifier: bundleIdentifier,
            created_from_ci: false,
            device_url: "itms-services://example.com",
            display_name: displayName,
            git_branch: gitBranch,
            icon_url: "https://example.com/icon.png",
            id: id,
            inserted_at: "2024-01-01T00:00:00Z",
            qr_code_url: "https://example.com/qr.png",
            supported_platforms: [.ios],
            url: url,
            version: version
        )
    }
}

final class MockGetLatestPreviewService: GetLatestPreviewServicing, @unchecked Sendable {
    var getLatestPreviewStub: ((String, String) async throws -> Components.Schemas.Preview?)?
    var getLatestPreviewCallCount = 0
    var getLatestPreviewLastBinaryId: String?
    var getLatestPreviewLastFullHandle: String?

    func getLatestPreview(
        binaryId: String,
        fullHandle: String
    ) async throws -> Components.Schemas.Preview? {
        getLatestPreviewCallCount += 1
        getLatestPreviewLastBinaryId = binaryId
        getLatestPreviewLastFullHandle = fullHandle
        return try await getLatestPreviewStub?(binaryId, fullHandle)
    }
}

final class MockAppStoreBuildChecker: AppStoreBuildChecking, @unchecked Sendable {
    var isAppStoreBuildResult = false

    func isAppStoreBuild() async -> Bool {
        isAppStoreBuildResult
    }
}

@Suite
struct TuistSDKTests {
    private func makeSDK(
        fullHandle: String = "myorg/myapp",
        apiKey: String = "test-api-key",
        serverURL: URL = URL(string: "https://test.tuist.dev")!,
        checkInterval: TimeInterval = 600,
        currentBinaryId: String? = "TEST-UUID-1234",
        mockService: MockGetLatestPreviewService = MockGetLatestPreviewService(),
        mockAppStoreChecker: MockAppStoreBuildChecker = MockAppStoreBuildChecker()
    ) -> TuistSDK {
        TuistSDK(
            fullHandle: fullHandle,
            apiKey: apiKey,
            serverURL: serverURL,
            checkInterval: checkInterval,
            currentBinaryId: currentBinaryId,
            getLatestPreviewService: mockService,
            appStoreBuildChecker: mockAppStoreChecker
        )
    }

    @Test
    func checkForUpdate_whenServiceReturnsNil_returnsNil() async throws {
        let mockService = MockGetLatestPreviewService()
        mockService.getLatestPreviewStub = { _, _ in nil }

        let sdk = makeSDK(currentBinaryId: "TEST-UUID-1234", mockService: mockService)

        let result = try await sdk.checkForUpdate()

        #expect(result == nil)
        #expect(mockService.getLatestPreviewCallCount == 1)
        #expect(mockService.getLatestPreviewLastBinaryId == "TEST-UUID-1234")
        #expect(mockService.getLatestPreviewLastFullHandle == "myorg/myapp")
    }

    @Test
    func checkForUpdate_whenPreviewHasCurrentBuild_returnsNil() async throws {
        let mockService = MockGetLatestPreviewService()
        let currentBinaryId = "CURRENT-UUID-1234"
        mockService.getLatestPreviewStub = { _, _ in
            .test(binaryIds: [currentBinaryId])
        }

        let sdk = makeSDK(currentBinaryId: currentBinaryId, mockService: mockService)

        let result = try await sdk.checkForUpdate()

        #expect(result == nil)
    }

    @Test
    func checkForUpdate_whenPreviewHasDifferentBuild_returnsUpdateInfo() async throws {
        let mockService = MockGetLatestPreviewService()
        let currentBinaryId = "CURRENT-UUID-1234"
        mockService.getLatestPreviewStub = { _, _ in
            .test(binaryIds: ["NEW-UUID-5678"], version: "1.2.0", gitBranch: "main")
        }

        let sdk = makeSDK(currentBinaryId: currentBinaryId, mockService: mockService)

        let result = try await sdk.checkForUpdate()

        #expect(result != nil)
        #expect(result?.id == "preview-1")
        #expect(result?.version == "1.2.0")
        #expect(result?.downloadURL == URL(string: "https://example.com/preview"))
    }

    @Test
    func checkForUpdate_whenNoBinaryId_throwsBinaryIdNotFound() async throws {
        let sdk = makeSDK(currentBinaryId: nil)

        await #expect(throws: TuistSDKError.binaryIdNotFound) {
            _ = try await sdk.checkForUpdate()
        }
    }

    @Test
    func checkForUpdate_whenServiceThrows_propagatesError() async throws {
        let mockService = MockGetLatestPreviewService()
        mockService.getLatestPreviewStub = { _, _ in
            throw GetLatestPreviewServiceError.unauthorized("Invalid token")
        }

        let sdk = makeSDK(mockService: mockService)

        await #expect(throws: GetLatestPreviewServiceError.self) {
            _ = try await sdk.checkForUpdate()
        }
    }

    @Test
    func checkForUpdate_whenPreviewHasNoBundleIdentifier_throwsInvalidURL() async throws {
        let mockService = MockGetLatestPreviewService()
        mockService.getLatestPreviewStub = { _, _ in
            .test(binaryIds: ["OTHER-UUID"], bundleIdentifier: nil)
        }

        let sdk = makeSDK(mockService: mockService)

        await #expect(throws: TuistSDKError.invalidURL) {
            _ = try await sdk.checkForUpdate()
        }
    }

    @Test
    func checkForUpdate_whenPreviewHasEmptyBuilds_returnsUpdateInfo() async throws {
        let mockService = MockGetLatestPreviewService()
        mockService.getLatestPreviewStub = { _, _ in .test() }

        let sdk = makeSDK(mockService: mockService)

        let result = try await sdk.checkForUpdate()

        #expect(result != nil)
        #expect(result?.id == "preview-1")
    }

    @Test
    func monitorUpdates_whenAppStoreBuild_doesNotCheck() async throws {
        let mockService = MockGetLatestPreviewService()
        mockService.getLatestPreviewStub = { _, _ in nil }

        let mockAppStoreChecker = MockAppStoreBuildChecker()
        mockAppStoreChecker.isAppStoreBuildResult = true

        let sdk = makeSDK(mockService: mockService, mockAppStoreChecker: mockAppStoreChecker)

        let task = sdk.monitorUpdates { _ in }

        // Give time for the async task to run
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()

        #expect(mockService.getLatestPreviewCallCount == 0)
    }

    @Test
    func monitorUpdates_whenNotAppStoreBuild_startsChecking() async throws {
        let mockService = MockGetLatestPreviewService()
        mockService.getLatestPreviewStub = { _, _ in nil }

        let mockAppStoreChecker = MockAppStoreBuildChecker()
        mockAppStoreChecker.isAppStoreBuildResult = false

        let sdk = makeSDK(mockService: mockService, mockAppStoreChecker: mockAppStoreChecker)

        let task = sdk.monitorUpdates { _ in }

        // Give time for the async task to run
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()

        #expect(mockService.getLatestPreviewCallCount == 1)
    }

    @Test
    func monitorUpdates_whenUpdateAvailable_callsCallback() async throws {
        let mockService = MockGetLatestPreviewService()
        mockService.getLatestPreviewStub = { _, _ in
            .test(binaryIds: ["DIFFERENT-UUID"])
        }

        let mockAppStoreChecker = MockAppStoreBuildChecker()
        mockAppStoreChecker.isAppStoreBuildResult = false

        let sdk = makeSDK(mockService: mockService, mockAppStoreChecker: mockAppStoreChecker)

        let expectation = Expectation()
        let task = sdk.monitorUpdates { updateInfo in
            #expect(updateInfo.id == "preview-1")
            expectation.fulfill()
        }

        await expectation.fulfillment(within: .seconds(1))
        task.cancel()
    }

    @Test
    func monitorUpdates_cancellation_stopsChecking() async throws {
        let mockService = MockGetLatestPreviewService()
        mockService.getLatestPreviewStub = { _, _ in nil }

        let mockAppStoreChecker = MockAppStoreBuildChecker()
        mockAppStoreChecker.isAppStoreBuildResult = false

        let sdk = makeSDK(checkInterval: 0.05, mockService: mockService, mockAppStoreChecker: mockAppStoreChecker)

        let task = sdk.monitorUpdates { _ in }

        // Give time for the first check
        try await Task.sleep(nanoseconds: 30_000_000)

        task.cancel()

        let countAfterCancel = mockService.getLatestPreviewCallCount

        // Wait to see if more checks happen
        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(mockService.getLatestPreviewCallCount == countAfterCancel)
    }
}

struct Expectation: Sendable {
    private let continuation: AsyncStream<Void>.Continuation
    private let stream: AsyncStream<Void>

    init() {
        var cont: AsyncStream<Void>.Continuation!
        stream = AsyncStream { cont = $0 }
        continuation = cont
    }

    func fulfill() {
        continuation.finish()
    }

    func fulfillment(within timeout: Duration) async {
        let task = Task {
            for await _ in stream { break }
        }

        let timeoutTask = Task {
            try? await Task.sleep(for: timeout)
            task.cancel()
        }

        await task.value
        timeoutTask.cancel()
    }
}
