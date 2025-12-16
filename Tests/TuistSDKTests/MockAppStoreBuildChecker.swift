import Foundation
@testable import TuistSDK

final class MockAppStoreBuildChecker: AppStoreBuildChecking, @unchecked Sendable {
    var isAppStoreBuildResult = false

    func isAppStoreBuild() async -> Bool {
        isAppStoreBuildResult
    }
}
