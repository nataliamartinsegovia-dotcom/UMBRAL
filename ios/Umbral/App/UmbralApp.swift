import SwiftUI

@main
struct UmbralApp: App {
    init() {
        BackgroundSync.register()
        BackgroundSync.reschedule()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
