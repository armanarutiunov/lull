import ServiceManagement
import SwiftUI

struct PopoverView: View {
    let monitor: Monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        .padding(14)
        .frame(width: 340)
        .onAppear { monitor.refresh() }
    }

    private func header(verdict: Verdict, snapshot: Snapshot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: verdict.level.symbolName)
                .font(.title2)
                .foregroundStyle(verdict.level.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(verdict.level.title)
                    .font(.headline)
                Text("Averaged over \(Self.format(span: snapshot.span)) · updated \(snapshot.takenAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func reasons(_ verdict: Verdict) -> some View {
        if verdict.reasons.isEmpty {
            Text("Nothing heavy is running. It's fine to turn off the display and leave it on the charger.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 8) {
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
        .font(.callout)
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
                .frame(width: 8, height: 8)
            Text(reason.message)
                .font(.callout)
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
                .controlSize(.small)
                .tint(confirming ? .red : nil)
            }
        }
    }
}

private struct StatsView: View {
    let snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !topApps.isEmpty {
                Text("Top CPU · % of one core")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(topApps) { app in
                    HStack {
                        Text(app.name).lineLimit(1)
                        Spacer()
                        Text("\(Int(app.cpuPercentOfCore.rounded()))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                ForEach(rows, id: \.label) { row in
                    GridRow {
                        Text(row.label)
                            .foregroundStyle(.secondary)
                        Text(row.value)
                            .monospacedDigit()
                    }
                }
            }
            .font(.caption)
            .padding(.top, 2)
        }
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
        switch snapshot.thermal {
        case .nominal: "Cool"
        case .fair: "Warm"
        case .serious: "Hot"
        case .critical: "Very hot"
        }
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
