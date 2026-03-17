import SwiftUI

@main
struct RunbookMacApp: App {
    @State private var store = RunbookStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .defaultSize(width: 1000, height: 700)
    }
}
