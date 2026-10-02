import SwiftUI

@main
struct LullApp: App {
    var body: some Scene {
        MenuBarExtra("Lull", systemImage: "moon.fill") {
            Text("Lull")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
