import SwiftUI
import TuistSDK

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    TuistSDK(
                        fullHandle: "tuist/tuist",
                        apiKey: "tuist_019b26b3-ec4d-782f-9c7b-b57d198a922b_8U9Je0IZuJm0ZyfiUkKhxfymVvk=",
                        serverURL: URL(string: "https://canary.tuist.dev")!
                    )
                    .monitorPreviewUpdates()
                }
        }
    }
}
