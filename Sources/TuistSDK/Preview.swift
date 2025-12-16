import Foundation

/// Preview.
public struct Preview: Sendable {
    /// The preview id
    public let id: String

    /// The preview version
    public let version: String?

    /// The URL to open the preview on device.
    public let deviceURL: URL

    public init(
        id: String,
        version: String?,
        deviceURL: URL
    ) {
        self.id = id
        self.version = version
        self.deviceURL = deviceURL
    }
}
