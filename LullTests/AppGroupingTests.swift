import Testing
@testable import Lull

@MainActor
struct AppGroupingTests {
    @Test func helperProcessesGroupUnderOutermostApp() {
        let path = "/Applications/Slack.app/Contents/Frameworks/Slack Helper (Renderer).app/Contents/MacOS/Slack Helper (Renderer)"
        #expect(AppGrouping.groupKey(for: path) == "/Applications/Slack.app")
    }

    @Test func plainExecutableIsItsOwnGroup() {
        let path = "/Users/me/Library/Android/sdk/emulator/qemu/darwin-aarch64/qemu-system-aarch64"
        #expect(AppGrouping.groupKey(for: path) == path)
    }

    @Test func groupSumsCPUAndSortsBusiestFirst() {
        let usage = AppGrouping.group([
            ProcessAverage(pid: 1, path: "/Applications/A.app/Contents/MacOS/A", cpuPercentOfCore: 10),
            ProcessAverage(pid: 2, path: "/Applications/A.app/Contents/Frameworks/H.app/Contents/MacOS/H", cpuPercentOfCore: 30),
            ProcessAverage(pid: 3, path: "/usr/bin/b", cpuPercentOfCore: 20),
        ])
        #expect(usage.map(\.name) == ["A", "b"])
        #expect(usage.first?.cpuPercentOfCore == 40)
        #expect(usage.first?.pids.sorted() == [1, 2])
    }
}
