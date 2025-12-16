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
                        apiKey: "tuist_019b139f-10ab-73c4-8845-4e230fe8ab8b_jC5U8ok8DvT6GhUta901ljUTUVE=",
                        serverURL: URL(string: "https://staging.tuist.dev")!
                    )
                    .monitorUpdates()
                }
        }
    }
}
