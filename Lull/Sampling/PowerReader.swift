import Foundation
import IOKit

enum PowerReader {
    static func read() -> PowerReading? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        func number(_ key: String) -> NSNumber? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? NSNumber
        }

        guard let percent = number("CurrentCapacity"), let amperage = number("InstantAmperage") else { return nil }
        return PowerReading(
            isOnAC: number("ExternalConnected")?.boolValue ?? false,
            batteryPercent: percent.intValue,
            // The registry stores negative currents as unsigned values; real readings fit in 16 bits.
            milliamps: Int(Int16(truncatingIfNeeded: amperage.int64Value))
        )
    }
}
