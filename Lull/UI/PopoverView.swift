import ServiceManagement
import SwiftUI

struct PopoverView: View {
    let monitor: Monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let verdict = monitor.verdict, let snapshot = monitor.snapshot {
                header(verdict: verdict, snapshot: snapshot)
                Divider()
                reasons(verdict)
                Divider()
                StatsView(snapshot: snapshot)
            } else {
                Text("Collecting data…")
                    .foregroundStyle(.secondary)
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 400)
        .onAppear { monitor.refresh() }
    }

    private func header(verdict: Verdict, snapshot: Snapshot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: verdict.level.symbolName)
                .font(.largeTitle)
                .foregroundStyle(verdict.level.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(verdict.level.title)
                    .font(.title2.weight(.semibold))
                Text("Averaged over \(Self.format(span: snapshot.span)) · updated \(snapshot.takenAt.formatted(date: .omitted, time: .shortened))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func reasons(_ verdict: Verdict) -> some View {
        if verdict.reasons.isEmpty {
            Text("Nothing heavy is running. It's fine to turn off the display and leave it on the charger.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(verdict.reasons) { reason in
                    ReasonRow(reason: reason)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            LaunchAtLoginToggle()
            Spacer()
            Button("Quit Lull") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
        }
        .font(.body)
    }

    static func format(span: TimeInterval) -> String {
        let minutes = Int((span / 60).rounded())
        return minutes < 1 ? "\(Int(span))s" : "\(minutes) min"
    }
}

private struct ReasonRow: View {
    let reason: Reason
    @State private var confirming = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(reason.level.color)
                .frame(width: 10, height: 10)
            Text(reason.message)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let app = reason.app {
                Button(confirming ? "Confirm" : "Quit") {
                    if confirming {
                        ProcessTerminator.quit(app)
                        confirming = false
                    } else {
                        confirming = true
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            confirming = false
                        }
                    }
                }
                .controlSize(.regular)
                .tint(confirming ? .red : nil)
            }
        }
    }
}

private struct StatsView: View {
    let snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !topApps.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 5) {
                    GridRow {
                        Text("Top CPU")
                        Text("Cores")
                            .gridColumnAlignment(.trailing)
                        Text("of the Mac")
                            .gridColumnAlignment(.trailing)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    ForEach(topApps) { app in
                        GridRow {
                            Text(app.name)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(app.coreUsage)
                                .foregroundStyle(.secondary)
                            Text(Self.percent(app.cpuPercentOfCore / Double(Self.coreCount)))
                        }
                        .font(.body)
                        .monospacedDigit()
                    }
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 5) {
                ForEach(rows, id: \.label) { row in
                    GridRow {
                        Text(row.label)
                            .foregroundStyle(.secondary)
                        Text(row.value)
                            .monospacedDigit()
                    }
                }
            }
            .font(.callout)
            .padding(.top, 4)
        }
    }

    private static let coreCount = max(ProcessInfo.processInfo.activeProcessorCount, 1)

    private static func percent(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f%%", value) : "\(Int(value.rounded()))%"
    }

    private var topApps: [AppUsage] {
        Array(snapshot.apps.prefix(3).filter { $0.cpuPercentOfCore >= 1 })
    }

    private var rows: [(label: String, value: String)] {
        var rows = [
            ("CPU", cpuValue),
            ("RAM", ramValue),
            ("Heat", heatValue),
        ]
        if let batteryValue {
            rows.append(("Battery", batteryValue))
        }
        return rows
    }

    private var cpuValue: String {
        let average = snapshot.machineCPUPercent.map { "\(Int($0.rounded()))% avg" } ?? "–"
        guard let recent = snapshot.recentCPUPercent else { return average }
        return "\(average) · \(Int(recent.rounded()))% now"
    }

    private var ramValue: String {
        let used = Double(snapshot.memoryUsedBytes) / 1_073_741_824
        let total = Double(snapshot.memoryTotalBytes) / 1_073_741_824
        let pressure = switch snapshot.memory {
        case .normal: "pressure normal"
        case .warning: "pressure high"
        case .critical: "pressure critical"
        }
        return String(format: "%.1f of %.0f GB · %@", used, total, pressure)
    }

    private var heatValue: String {
        let state = switch snapshot.thermal {
        case .nominal: "cool"
        case .fair: "warm"
        case .serious: "hot"
        case .critical: "very hot"
        }
        let parts = [
            snapshot.temperature.cpuCelsius.map { "CPU \(Int($0.rounded()))°C" },
            snapshot.temperature.batteryCelsius.map { "battery \(Int($0.rounded()))°C" },
        ].compactMap(\.self)
        return (parts + [state]).joined(separator: " · ")
    }

    private var batteryValue: String? {
        guard let power = snapshot.power else { return nil }
        let source = power.isOnAC ? "on charger" : "on battery"
        let flow = switch power.milliamps {
        case ..<0: "draining \(-power.milliamps) mA"
        case 0: "idle"
        default: "charging \(power.milliamps) mA"
        }
        return "\(power.batteryPercent)% · \(source) · \(flow)"
    }
}

private struct LaunchAtLoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Launch at login", isOn: $enabled)
            .toggleStyle(.checkbox)
            .onChange(of: enabled) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    enabled = SMAppService.mainApp.status == .enabled
                }
            }
    }
}
