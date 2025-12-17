import Foundation
import Testing

@testable import TuistSDK

@Suite
struct TuistSDKTests {
    private let getLatestPreviewService = MockGetLatestPreviewService()
    private let appStoreBuildChecker = MockAppStoreBuildChecker()

    private func makeSDK(
        fullHandle: String = "myorg/myapp",
        apiKey: String = "test-api-key",
        serverURL: URL = URL(string: "https://test.tuist.dev")!,
        checkInterval: TimeInterval = 600,
        currentBinaryId: String? = "TEST-UUID-1234",
        currentBuildVersion: String? = "1"
    ) -> TuistSDK {
        TuistSDK(
            fullHandle: fullHandle,
            apiKey: apiKey,
            serverURL: serverURL,
            checkInterval: checkInterval,
            currentBinaryId: currentBinaryId,
            currentBuildVersion: currentBuildVersion,
            getLatestPreviewService: getLatestPreviewService,
            appStoreBuildChecker: appStoreBuildChecker
        )
    }

    @Test
    func checkForPreviewUpdate_whenServiceReturnsNil_returnsNil() async throws {
        getLatestPreviewService.getLatestPreviewStub = { binaryId, buildVersion, fullHandle in
            #expect(binaryId == "TEST-UUID-1234")
            #expect(buildVersion == "1")
            #expect(fullHandle == "myorg/myapp")
            return nil
        }

        let result = try await makeSDK().checkForPreviewUpdate()

        #expect(result == nil)
    }

    @Test
    func checkForPreviewUpdate_whenPreviewHasCurrentBuild_returnsNil() async throws {
        let currentBinaryId = "CURRENT-UUID-1234"
        getLatestPreviewService.getLatestPreviewStub = { _, _, _ in
            .test(binaryIds: [currentBinaryId])
        }

        let result = try await makeSDK(currentBinaryId: currentBinaryId).checkForPreviewUpdate()

        #expect(result == nil)
    }

    @Test
    func checkForPreviewUpdate_whenPreviewHasDifferentBuild_returnsUpdateInfo() async throws {
        getLatestPreviewService.getLatestPreviewStub = { _, _, _ in
            .test(binaryIds: ["NEW-UUID-5678"], version: "1.2.0", gitBranch: "main")
        }

        let result = try await makeSDK().checkForPreviewUpdate()

        #expect(result != nil)
        #expect(result?.id == "preview-1")
        #expect(result?.version == "1.2.0")
        #expect(result?.deviceURL == URL(string: "itms-services://example.com"))
    }

    @Test
    func checkForPreviewUpdate_whenNoBinaryId_throwsBinaryIdNotFound() async throws {
        await #expect(throws: TuistSDKError.binaryIdNotFound) {
            _ = try await makeSDK(currentBinaryId: nil).checkForPreviewUpdate()
        }
    }

    @Test
    func monitorPreviewUpdates_whenAppStoreBuild_doesNotCheck() async throws {
        getLatestPreviewService.getLatestPreviewStub = { _, _, _ in
            Issue.record("Service should not be called for App Store builds")
            return nil
        }
        appStoreBuildChecker.isAppStoreBuildResult = true

        let task = makeSDK().monitorPreviewUpdates { _ in }

        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
    }

    @Test
    func monitorPreviewUpdates_whenNotAppStoreBuild_startsChecking() async throws {
        appStoreBuildChecker.isAppStoreBuildResult = false

        await confirmation { confirm in
            getLatestPreviewService.getLatestPreviewStub = { _, _, _ in
                confirm()
                return nil
            }

            let task = makeSDK().monitorPreviewUpdates { _ in }

            try? await Task.sleep(nanoseconds: 100_000_000)
            task.cancel()
        }
    }

    @Test
    func monitorPreviewUpdates_whenUpdateAvailable_callsCallback() async throws {
        getLatestPreviewService.getLatestPreviewStub = { _, _, _ in
            .test(binaryIds: ["DIFFERENT-UUID"])
        }
        appStoreBuildChecker.isAppStoreBuildResult = false

        await confirmation { confirm in
            let task = makeSDK().monitorPreviewUpdates { updateInfo in
                #expect(updateInfo.id == "preview-1")
                confirm()
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
            task.cancel()
        }
    }

    @Test
    func checkForPreviewUpdate_whenNoBuildVersion_throwsBuildVersionNotFound() async throws {
        await #expect(throws: TuistSDKError.buildVersionNotFound) {
            _ = try await makeSDK(currentBuildVersion: nil).checkForPreviewUpdate()
        }
    }
}
