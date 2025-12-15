import Foundation
import StoreKit

protocol AppStoreBuildChecking: Sendable {
    func isAppStoreBuild() async -> Bool
}

struct AppStoreBuildChecker: AppStoreBuildChecking {
    func isAppStoreBuild() async -> Bool {
        guard let appTransaction = try? await AppTransaction.shared else {
            return false
        }
        switch appTransaction {
        case .verified:
            return true
        case .unverified:
            return false
        }
    }
}
