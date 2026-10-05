import Foundation

struct StatusFile: Codable, Equatable, Sendable {
    struct Reason: Codable, Equatable, Sendable {
        let level: String
        let message: String
    }

    struct App: Codable, Equatable, Sendable {
        let name: String
        let coreUsage: String
        let percentOfCore: Double
        let percentOfMac: Double
    }

    struct CPU: Codable, Equatable, Sendable {
        let averagePercent: Double?
        let nowPercent: Double?
        let coreCount: Int
        let topApps: [App]
    }

    struct Memory: Codable, Equatable, Sendable {
        let usedBytes: UInt64
        let totalBytes: UInt64
        let pressure: String
    }

    struct Heat: Codable, Equatable, Sendable {
        let state: String
        let cpuCelsius: Double?
        let batteryCelsius: Double?
    }

    struct Battery: Codable, Equatable, Sendable {
        let percent: Int
        let onCharger: Bool
        let milliamps: Int
    }

    let level: String
    let title: String
    let updatedAt: Date
    let windowSeconds: Int
    let reasons: [Reason]
    let cpu: CPU
    let memory: Memory
    let heat: Heat
    let battery: Battery?

    static var url: URL {
        URL.applicationSupportDirectory.appending(path: "Lull/status.json")
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension StatusFile {
    init(snapshot: Snapshot, verdict: Verdict, coreCount: Int) {
        level = verdict.level.name
        title = verdict.level.title
        updatedAt = snapshot.takenAt
        windowSeconds = Int(snapshot.span.rounded())
        reasons = verdict.reasons.map { Reason(level: $0.level.name, message: $0.message) }
        cpu = CPU(
            averagePercent: snapshot.machineCPUPercent.map(Self.rounded),
            nowPercent: snapshot.recentCPUPercent.map(Self.rounded),
            coreCount: coreCount,
            topApps: snapshot.apps.prefix(5).map { app in
                App(
                    name: app.name,
                    coreUsage: app.coreUsage,
                    percentOfCore: Self.rounded(app.cpuPercentOfCore),
                    percentOfMac: Self.rounded(app.cpuPercentOfCore / Double(max(coreCount, 1)))
                )
            }
        )
        memory = Memory(
            usedBytes: snapshot.memoryUsedBytes,
            totalBytes: snapshot.memoryTotalBytes,
            pressure: snapshot.memory.name
        )
        heat = Heat(
            state: snapshot.thermal.name,
            cpuCelsius: snapshot.temperature.cpuCelsius.map(Self.rounded),
            batteryCelsius: snapshot.temperature.batteryCelsius.map(Self.rounded)
        )
        battery = snapshot.power.map {
            Battery(percent: $0.batteryPercent, onCharger: $0.isOnAC, milliamps: $0.milliamps)
        }
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    func write() throws {
        let url = Self.url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(self).write(to: url, options: .atomic)
    }

    static func read() throws -> StatusFile {
        try decoder.decode(StatusFile.self, from: Data(contentsOf: url))
    }

    func summary(now: Date = .now) -> String {
        let symbol = switch level {
        case "safe": "🟢"
        case "caution": "🟡"
        default: "🔴"
        }
        let age = Int(now.timeIntervalSince(updatedAt))
        var lines = ["\(symbol) \(title)  (updated \(age)s ago, averaged over \(windowSeconds < 60 ? "\(windowSeconds)s" : "\(windowSeconds / 60) min"))"]
        if age > 120 {
            lines.append("⚠️ This is stale. Lull may not be running.")
        }
        lines += reasons.map { "• \($0.message)" }
        lines.append("")
        let average = cpu.averagePercent.map { "\($0)% avg" } ?? "–"
        let current = cpu.nowPercent.map { " · \($0)% now" } ?? ""
        lines.append("CPU      \(average)\(current) across \(cpu.coreCount) cores")
        for app in cpu.topApps.prefix(3) {
            lines.append("         \(app.name): \(app.coreUsage), \(app.percentOfMac)% of the Mac")
        }
        let gigabyte = 1_073_741_824.0
        lines.append(String(format: "RAM      %.1f of %.0f GB · pressure %@", Double(memory.usedBytes) / gigabyte, Double(memory.totalBytes) / gigabyte, memory.pressure))
        let temperatures = [
            heat.cpuCelsius.map { "CPU \(Int($0.rounded()))°C" },
            heat.batteryCelsius.map { "battery \(Int($0.rounded()))°C" },
        ].compactMap(\.self)
        lines.append("Heat     " + (temperatures + [heat.state]).joined(separator: " · "))
        if let battery {
            let flow = switch battery.milliamps {
            case ..<0: "draining \(-battery.milliamps) mA"
            case 0: "idle"
            default: "charging \(battery.milliamps) mA"
            }
            lines.append("Battery  \(battery.percent)% · \(battery.onCharger ? "on charger" : "on battery") · \(flow)")
        }
        return lines.joined(separator: "\n")
    }
}

extension MemoryPressure {
    var name: String {
        switch self {
        case .normal: "normal"
        case .warning: "warning"
        case .critical: "critical"
        }
    }
}

extension Thermal {
    var name: String {
        switch self {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        }
    }
}

extension Level {
    var name: String {
        switch self {
        case .safe: "safe"
        case .caution: "caution"
        case .unsafe: "unsafe"
        }
    }
}
