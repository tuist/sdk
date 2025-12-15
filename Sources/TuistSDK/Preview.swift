import Foundation

/// Preview.
public struct Preview: Sendable {
    /// The preview id
    public let id: String
    
    /// The preview version
    public let version: String?
    
    /// The URL to download the preview.
    public let downloadURL: URL

    public init(
        id: String,
        version: String?,
        downloadURL: URL
    ) {
        self.id = id
        self.version = version
        self.downloadURL = downloadURL
    }
}
