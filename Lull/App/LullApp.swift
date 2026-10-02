import SwiftUI

@main
struct LullApp: App {
    @State private var monitor: Monitor = {
        let monitor = Monitor()
        monitor.start()
        return monitor
    }()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
        } label: {
            Image(nsImage: (monitor.verdict?.level ?? .safe).menuBarImage)
        }
        .menuBarExtraStyle(.window)
    }
}
