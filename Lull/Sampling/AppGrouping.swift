import AppKit

enum AppGrouping {
    static func group(_ processes: [ProcessAverage]) -> [AppUsage] {
        let runningApps = Dictionary(
            NSWorkspace.shared.runningApplications.compactMap { app in app.bundleURL.map { ($0.path, app) } },
            uniquingKeysWith: { first, _ in first }
        )

        let grouped = Dictionary(grouping: processes) { groupKey(for: $0.path) }
        return grouped.map { key, members in
            let isBundle = key.hasSuffix(".app")
            let name = isBundle
                ? runningApps[key]?.localizedName ?? URL(fileURLWithPath: key).deletingPathExtension().lastPathComponent
                : URL(fileURLWithPath: key).lastPathComponent
            return AppUsage(
                id: key,
                name: name,
                cpuPercentOfCore: members.reduce(0) { $0 + $1.cpuPercentOfCore },
                pids: members.map(\.pid),
                bundleURL: isBundle ? URL(fileURLWithPath: key) : nil
            )
        }
        .sorted { $0.cpuPercentOfCore > $1.cpuPercentOfCore }
    }

    // Helpers live inside their parent bundle (Slack.app/…/Slack Helper.app), so the outermost
    // .app is the one the user recognises and can quit.
    static func groupKey(for path: String) -> String {
        guard let range = path.range(of: ".app/") else { return path }
        return String(path[..<range.lowerBound]) + ".app"
    }
}
