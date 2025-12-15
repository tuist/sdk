import Foundation
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
