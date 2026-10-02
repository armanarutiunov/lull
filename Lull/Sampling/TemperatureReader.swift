import Foundation
import IOKit.hid

// Apple Silicon has no public temperature API. These IOHIDEventSystem calls are private but
// stable and need no admin rights; they are looked up at runtime so a missing symbol only
// hides the temperature instead of crashing.
enum TemperatureReader {
    struct Reading: Equatable, Sendable {
        let cpuCelsius: Double?
        let batteryCelsius: Double?
    }

    private typealias CreateClient = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias SetMatching = @convention(c) (AnyObject, CFDictionary) -> Void
    private typealias CopyServices = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
    private typealias CopyEvent = @convention(c) (AnyObject, Int64, Int32, Int64) -> Unmanaged<AnyObject>?
    private typealias GetFloatValue = @convention(c) (AnyObject, Int32) -> Double

    private static let temperatureEventType: Int64 = 15

    private struct API {
        // Services borrow the client's internal lock, so the client must outlive them.
        let client: AnyObject
        let copyEvent: CopyEvent
        let getFloatValue: GetFloatValue
        let services: [(name: String, service: AnyObject)]
    }

    private static let api: API? = {
        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let pointer = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
            return unsafeBitCast(pointer, to: type)
        }
        guard let create = symbol("IOHIDEventSystemClientCreate", as: CreateClient.self),
              let setMatching = symbol("IOHIDEventSystemClientSetMatching", as: SetMatching.self),
              let copyServices = symbol("IOHIDEventSystemClientCopyServices", as: CopyServices.self),
              let copyEvent = symbol("IOHIDServiceClientCopyEvent", as: CopyEvent.self),
              let getFloatValue = symbol("IOHIDEventGetFloatValue", as: GetFloatValue.self),
              let client = create(kCFAllocatorDefault)?.takeRetainedValue()
        else { return nil }

        setMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        let services = (copyServices(client)?.takeRetainedValue() as? [AnyObject] ?? []).compactMap { service in
            let product = IOHIDServiceClientCopyProperty(unsafeBitCast(service, to: IOHIDServiceClient.self), "Product" as CFString)
            return (product as? String).map { (name: $0, service: service) }
        }
        return API(client: client, copyEvent: copyEvent, getFloatValue: getFloatValue, services: services)
    }()

    static func read() -> Reading {
        guard let api else { return Reading(cpuCelsius: nil, batteryCelsius: nil) }
        var cpu: [Double] = []
        var battery: [Double] = []
        for (name, service) in api.services {
            let isCPU = name.contains("tdie")
            let isBattery = name.contains("battery")
            guard isCPU || isBattery,
                  let event = api.copyEvent(service, temperatureEventType, 0, 0)?.takeRetainedValue()
            else { continue }
            let celsius = api.getFloatValue(event, Int32(temperatureEventType << 16))
            // Some sensors report placeholder values far outside a physical range.
            guard (1...130).contains(celsius) else { continue }
            if isCPU { cpu.append(celsius) } else { battery.append(celsius) }
        }
        return Reading(cpuCelsius: average(cpu), batteryCelsius: average(battery))
    }

    private static func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
