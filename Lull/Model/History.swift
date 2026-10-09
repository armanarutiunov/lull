import Foundation

struct HistoryEntry: Codable, Equatable, Sendable {
    struct App: Codable, Equatable, Sendable {
        let name: String
        let percentOfCore: Double
    }

    let time: Date
    let level: String
    let cpuAveragePercent: Double?
    let topApps: [App]
    let reasons: [String]
    let cpuCelsius: Double?
    let memoryUsedBytes: UInt64
    let memoryPressure: String
    let batteryPercent: Int?
    let onCharger: Bool?
    let batteryMilliamps: Int?
}

extension HistoryEntry {
    init(status: StatusFile) {
        time = status.updatedAt
        level = status.level
        cpuAveragePercent = status.cpu.averagePercent
        topApps = status.cpu.topApps.prefix(3).map { App(name: $0.name, percentOfCore: $0.percentOfCore) }
        reasons = status.reasons.map(\.message)
        cpuCelsius = status.heat.cpuCelsius
        memoryUsedBytes = status.memory.usedBytes
        memoryPressure = status.memory.pressure
        batteryPercent = status.battery?.percent
        onCharger = status.battery?.onCharger
        batteryMilliamps = status.battery?.milliamps
    }
}

struct History: Codable, Equatable, Sendable {
    static let interval: TimeInterval = 5 * 60
    static let retention: TimeInterval = 24 * 60 * 60

    private(set) var entries: [HistoryEntry] = []

    @discardableResult
    mutating func record(_ entry: HistoryEntry) -> Bool {
        if let last = entries.last, entry.time.timeIntervalSince(last.time) < Self.interval {
            return false
        }
        entries.append(entry)
        entries.removeAll { entry.time.timeIntervalSince($0.time) >= Self.retention }
        return true
    }
}

extension History {
    static var url: URL {
        URL.applicationSupportDirectory.appending(path: "Lull/history.json")
    }

    static func load() -> History {
        (try? StatusFile.decoder.decode(History.self, from: Data(contentsOf: url))) ?? History()
    }

    func write() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: Self.url, options: .atomic)
    }

    func table(timeZone: TimeZone = .current) -> String {
        guard !entries.isEmpty else { return "No history yet. Lull records a reading every 5 minutes." }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH:mm"
        formatter.timeZone = timeZone
        let header = "Time        Level  CPU    Temp   Battery           Top app"
        let rows = entries.map { entry in
            let symbol = switch entry.level {
            case "safe": "🟢"
            case "caution": "🟡"
            default: "🔴"
            }
            let cpu = entry.cpuAveragePercent.map { String(format: "%5.1f%%", $0) } ?? "   –  "
            let temp = entry.cpuCelsius.map { String(format: "%3.0f°C", $0) } ?? "   – "
            let battery: String = if let percent = entry.batteryPercent {
                "\(percent)% \(entry.onCharger == true ? "AC" : "batt") \(entry.batteryMilliamps ?? 0)mA"
            } else {
                "–"
            }
            let app = entry.topApps.first.map { "\($0.name) \(Int($0.percentOfCore.rounded()))%" } ?? ""
            return [
                formatter.string(from: entry.time).padding(toLength: 11, withPad: " ", startingAt: 0),
                symbol.padding(toLength: 5, withPad: " ", startingAt: 0),
                cpu,
                " " + temp,
                "  " + battery.padding(toLength: 17, withPad: " ", startingAt: 0),
                app,
            ].joined(separator: " ")
        }
        return ([header] + rows).joined(separator: "\n")
    }
}
