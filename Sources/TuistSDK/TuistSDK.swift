import Foundation
import MachO

#if canImport(UIKit)
    import UIKit
#endif

/// TuistSDK provides automatic update checking for Tuist Previews.
///
/// Use this SDK to detect when a newer
/// version is available.
///
/// Example usage:
/// ```swift
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .task {
///                     TuistSDK(
///                        fullHandle: "myorg/myapp",
///                        apiKey: "your-api-key"
///                     )
///                     .monitorUpdates()
///                 }
///         }
///     }
/// }
/// ```
public struct TuistSDK: Sendable {
    /// The Tuist server URL.
    private let serverURL: URL

    /// The full handle in the format "account-handle/project-handle".
    private let fullHandle: String

    /// The API key (account token) for authentication.
    private let apiKey: String

    /// The interval between update checks. Default is 600 seconds (10 minutes).
    public let checkInterval: TimeInterval

    private let currentBinaryId: String?
    private let getLatestPreviewService: GetLatestPreviewServicing
    private let appStoreBuildChecker: AppStoreBuildChecking

    /// Creates a new TuistSDK instance.
    ///
    /// - Parameters:
    ///   - fullHandle: The full handle in the format "account-handle/project-handle".
    ///   - apiKey: The API key (account token) for authentication.
    ///   - serverURL: The Tuist server URL. Defaults to https://tuist.dev
    ///   - checkInterval: The interval between update checks. Default is 600 seconds (10 minutes).
    public init(
        fullHandle: String,
        apiKey: String,
        serverURL: URL = URL(string: "https://tuist.dev")!,
        checkInterval: TimeInterval = 600
    ) {
        self.serverURL = serverURL
        self.fullHandle = fullHandle
        self.apiKey = apiKey
        self.checkInterval = checkInterval
        currentBinaryId = Self.extractBinaryId()
        getLatestPreviewService = GetLatestPreviewService(serverURL: serverURL, apiKey: apiKey)
        appStoreBuildChecker = AppStoreBuildChecker()
    }

    init(
        fullHandle: String,
        apiKey: String,
        serverURL: URL,
        checkInterval: TimeInterval,
        currentBinaryId: String?,
        getLatestPreviewService: GetLatestPreviewServicing,
        appStoreBuildChecker: AppStoreBuildChecking
    ) {
        self.serverURL = serverURL
        self.fullHandle = fullHandle
        self.apiKey = apiKey
        self.checkInterval = checkInterval
        self.currentBinaryId = currentBinaryId
        self.getLatestPreviewService = getLatestPreviewService
        self.appStoreBuildChecker = appStoreBuildChecker
    }

    /// Monitors new preview updates. Returns a task that can be cancelled to stop checking.
    ///
    /// - Parameter onUpdateAvailable: Called on the main thread when an update is available.
    /// - Returns: A task that runs until cancelled. Call `cancel()` on it to stop update checking.
    ///
    /// - Note: Update checking is disabled on simulators and App Store builds.
    @discardableResult
    public func monitorUpdates(
        onUpdateAvailable: @MainActor @Sendable @escaping (Preview) -> Void
    ) -> Task<Void, any Error> {
        Task {
            #if targetEnvironment(simulator)
                return
            #else
                if await appStoreBuildChecker.isAppStoreBuild() {
                    return
                }

                let interval: Duration = .seconds(checkInterval)

                while !Task.isCancelled {
                    let start = ContinuousClock.now

                    if let preview = try await checkForUpdate() {
                        await onUpdateAvailable(preview)
                    }

                    let elapsed = ContinuousClock.now - start
                    let remaining = interval - elapsed

                    if remaining > .zero {
                        try? await Task.sleep(for: remaining)
                    }
                }
            #endif
        }
    }

    #if canImport(UIKit)
        /// Starts periodic update checking with a default alert. Returns a task that can be cancelled.
        ///
        /// - Returns: A task that runs until cancelled. Call `cancel()` on it to stop update checking.
        ///
        /// - Note: Update checking is disabled on simulators and App Store builds.
        @discardableResult
        public func monitorUpdates() -> Task<Void, any Error> {
            monitorUpdates { preview in
                showDefaultUpdateAlert(preview: preview)
            }
        }

        private static let ignoredPreviewIdKey = "TuistSDK.ignoredPreviewId"

        @MainActor
        private func showDefaultUpdateAlert(preview: Preview) {
            let ignoredPreviewId = UserDefaults.standard.string(forKey: Self.ignoredPreviewIdKey)
            if ignoredPreviewId == preview.id {
                return
            }

            let title = "Update Available"
            let message: String
            if let version = preview.version {
                message = "A new version (\(version)) is available. Would you like to install it?"
            } else {
                message = "A new version is available. Would you like to install it?"
            }

            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

            alert.addAction(
                UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    UserDefaults.standard.set(preview.id, forKey: Self.ignoredPreviewIdKey)
                }
            )
            alert.addAction(
                UIAlertAction(title: "Install", style: .default) { _ in
                    UIApplication.shared.open(preview.deviceURL)
                }
            )

            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                let rootViewController = windowScene.windows.first?.rootViewController
            else {
                return
            }

            var presenter = rootViewController
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(alert, animated: true)
        }
    #endif

    /// Performs a single update check.
    ///
    /// - Returns: `Preview` if an update is available, nil otherwise.
    public func checkForUpdate() async throws -> Preview? {
        guard let binaryId = currentBinaryId else {
            throw TuistSDKError.binaryIdNotFound
        }

        guard let latestPreview = try await getLatestPreviewService.getLatestPreview(
            binaryId: binaryId,
            fullHandle: fullHandle
        )
        else {
            return nil
        }

        let hasCurrentBuild = latestPreview.builds.contains(where: { $0.binary_id == binaryId })
        guard !hasCurrentBuild else { return nil }

        guard let deviceURL = URL(string: latestPreview.device_url) else { throw TuistSDKError.invalidURL }
        return Preview(
            id: latestPreview.id,
            version: latestPreview.version,
            deviceURL: deviceURL
        )
    }

    private static func extractBinaryId() -> String? {
        for i in 0 ..< _dyld_image_count() {
            guard let header = _dyld_get_image_header(i) else { continue }

            let headerPtr = UnsafeRawPointer(header)

            let is64Bit = header.pointee.magic == MH_MAGIC_64 || header.pointee.magic == MH_CIGAM_64

            var loadCommandPtr: UnsafeRawPointer
            if is64Bit {
                loadCommandPtr = headerPtr.advanced(by: MemoryLayout<mach_header_64>.size)
            } else {
                loadCommandPtr = headerPtr.advanced(by: MemoryLayout<mach_header>.size)
            }

            for _ in 0 ..< header.pointee.ncmds {
                let loadCommand = loadCommandPtr.assumingMemoryBound(to: load_command.self).pointee

                if loadCommand.cmd == LC_UUID {
                    let uuidCommand = loadCommandPtr.assumingMemoryBound(to: uuid_command.self)
                        .pointee
                    let uuid = UUID(uuid: uuidCommand.uuid)
                    return uuid.uuidString
                }

                loadCommandPtr = loadCommandPtr.advanced(by: Int(loadCommand.cmdsize))
            }
        }
        return nil
    }
}

/// Errors that can occur when using TuistSDK.
public enum TuistSDKError: LocalizedError, Equatable {
    case binaryIdNotFound
    case invalidURL

    public var errorDescription: String? {
        switch self {
        case .binaryIdNotFound:
            return "Could not extract binary ID from the running executable"
        case .invalidURL:
            return "Invalid server URL"
        }
    }
}
