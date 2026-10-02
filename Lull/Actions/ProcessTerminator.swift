import AppKit

enum ProcessTerminator {
    static func quit(_ app: AppUsage) {
        if let bundleURL = app.bundleURL {
            let running = NSWorkspace.shared.runningApplications.filter { $0.bundleURL == bundleURL }
            if !running.isEmpty {
                running.forEach { $0.terminate() }
                return
            }
        }
        app.pids.forEach { kill($0, SIGTERM) }
    }
}
