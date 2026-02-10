import Accelerate
import Foundation
import IOKit

let LX_KEY = "CurrentLux"
let AMBR_KEY = "AmbientBrightness"
let kAmbientLightSensorEvent: Int64 = 12
let kAmbientLightSensorEventShifted: Int32 = 12 << 16

let LUX_INTERNAL_SENSOR_MATCHING_DICT = [kIOPropertyExistsMatchKey: LX_KEY] as NSDictionary
let AMBIENT_INTERNAL_SENSOR_MATCHING_DICT = [kIOPropertyExistsMatchKey: AMBR_KEY] as NSDictionary
let knownToWork: Set<String> = ["StudioDisplay", "ProDisplayXDR", "LG UltraFine", "LED Cinema", "Thunderbolt"]

@inline(__always) @inlinable
func cap<T: Comparable>(_ number: T, minVal: T, maxVal: T) -> T {
    max(min(number, maxVal), minVal)
}

@usableFromInline let DOUBLE_PACK_FACTOR = Double(bitPattern: 0x3EF0_0000_0000_0000)

@inline(__always) @inlinable
func unpackDouble(_ n: Double) -> Double {
    DOUBLE_PACK_FACTOR * Double(n)
}

struct InternalSensor {
    let service: io_service_t
    let client: IOHIDServiceClient?
    let property: String
    let needsUnpacking: Bool

    var lux: Double? {
        if service == 0, let client, let event = IOHIDServiceClientCopyEvent(client, kAmbientLightSensorEvent, 0, 0) {
            return IOHIDEventGetFloatValue(event, kAmbientLightSensorEventShifted)
        }
        guard let light: Double = IOServiceProperty(service, property) else {
            return nil
        }

        return needsUnpacking ? cap(unpackDouble(light), minVal: 0, maxVal: 30000) : light
    }
}

var luxWindowValues: [Double] = []
var windowAverageSize = 15

func computeLuxWindowAverage(lux: Double? = nil) -> Double? {
    guard let lux else { return nil }
    guard !luxWindowValues.isEmpty else {
        luxWindowValues.append(lux)
        return lux
    }

    luxWindowValues.append(lux)
    if luxWindowValues.count > windowAverageSize {
        luxWindowValues.removeFirst()
    }
    var sum: Double = 0
    vDSP_sveD(luxWindowValues, 1, &sum, vDSP_Length(luxWindowValues.count))
    return sum / Double(luxWindowValues.count)
}

func getInternalSensor() -> InternalSensor? {
    if let client = ALCALSCopyALSServiceClient()?.takeRetainedValue(),
       let event = IOHIDServiceClientCopyEvent(client, kAmbientLightSensorEvent, 0, 0),
       IOHIDEventGetFloatValue(event, kAmbientLightSensorEventShifted) >= 0
    {
        return InternalSensor(service: 0, client: client, property: LX_KEY, needsUnpacking: false)
    }
    let sensorService = IOServiceGetMatchingService(kIOMasterPortDefault, LUX_INTERNAL_SENSOR_MATCHING_DICT)
    if sensorService != 0 {
        return InternalSensor(service: sensorService, client: nil, property: LX_KEY, needsUnpacking: false)
    }

    #if arch(arm64)
        let dispService = IOServiceFirstMatchingWhere(AMBIENT_INTERNAL_SENSOR_MATCHING_DICT) { s in
            guard let light: Double = IOServiceProperty(s, AMBR_KEY), light != 0x10000, light != 0x12C0000, light >= 0 else {
                return false
            }

            if let name = IOServiceParentName(s), name == "disp0" {
                return true
            }

            guard let attrs: [String: Any] = IOServiceProperty(s, "DisplayAttributes"),
                  let productAttributes = attrs["ProductAttributes"] as? [String: Any],
                  let name = productAttributes["ProductName"] as? String,
                  knownToWork.contains(name)
            else {
                return false
            }
            return true
        }

        guard let dispService else {
            return nil
        }
        return InternalSensor(service: dispService, client: nil, property: AMBR_KEY, needsUnpacking: true)
    #else
        return nil
    #endif
}

var internalSensor: InternalSensor? {
    didSet {
        if let sensor = internalSensor, sensor.service != 0 {
            IOObjectRelease(sensor.service)
        }
    }
}

func IOServiceProperty<T>(_ service: io_service_t, _ key: String) -> T? {
    guard let cfProp = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)
    else {
        return nil
    }
    guard let value = cfProp.takeRetainedValue() as? T else {
        cfProp.release()
        return nil
    }
    return value
}

func IOServiceParentName(_ service: io_service_t) -> String? {
    var serv: io_service_t = 0
    IORegistryEntryGetParentEntry(service, kIOServicePlane, &serv)

    guard serv != 0 else { return nil }
    return IOServiceName(serv)
}

func IOServiceFirstMatchingWhere(_ matching: CFDictionary, where predicate: (io_service_t) -> Bool) -> io_service_t? {
    var ioIterator = io_iterator_t()

    guard IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &ioIterator) == KERN_SUCCESS
    else {
        return nil
    }

    defer { IOObjectRelease(ioIterator) }
    while case let ioService = IOIteratorNext(ioIterator), ioService != 0 {
        if predicate(ioService) {
            return ioService
        }
        IOObjectRelease(ioService)
    }
    return nil
}

func IOServiceName(_ service: io_service_t) -> String? {
    let deviceNamePtr = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
    defer { deviceNamePtr.deallocate() }
    deviceNamePtr.initialize(repeating: 0, count: MemoryLayout<io_name_t>.size)
    defer { deviceNamePtr.deinitialize(count: MemoryLayout<io_name_t>.size) }

    let kr = IORegistryEntryGetName(service, deviceNamePtr)
    if kr != KERN_SUCCESS {
        return nil
    }

    return String(cString: deviceNamePtr)
}

// MARK: - CLI Argument Parser

var isListening = false
var isBare = false
var interval: TimeInterval = 1.0
var i = 1
while i < CommandLine.arguments.count {
    let arg = CommandLine.arguments[i]

    switch arg {
    case "-l", "--listen":
        isListening = true
    case "-i", "--interval":
        i += 1
        if i < CommandLine.arguments.count, let intervalValue = Double(CommandLine.arguments[i]) {
            interval = intervalValue
        } else {
            fputs("Error: --interval requires a numeric value\n", stderr)
            exit(1)
        }
    case "--window-average":
        i += 1
        if i < CommandLine.arguments.count, let size = Int(CommandLine.arguments[i]), size > 0 {
            windowAverageSize = size
        } else {
            fputs("Error: --window-average requires a positive integer\n", stderr)
            exit(1)
        }
    case "--bare":
        isBare = true
    case "-h", "--help":
        print("""
        ALS - Ambient Light Sensor Reader

        Usage: ALS [OPTIONS]

        Options:
          -l, --listen              Read lux values periodically
          -i, --interval SECONDS    Set the polling interval (default: 1 second)
          --window-average SIZE     Set the window average size (default: 15)
          --bare                    Print only the average value (for piping)
          -h, --help                Show this help message

        Examples:
          ALS                           Print current lux and exit
          ALS --listen                  Print lux every second
          ALS --listen --interval 0.5   Print lux every 500ms
          ALS --window-average 30       Print current lux with 30-sample average
          ALS --bare                    Print only average value
          ALS --listen --bare           Print average values continuously
        """)
        exit(0)
    default:
        fputs("Error: Unknown argument '\(arg)'\n", stderr)
        fputs("Use --help for usage information\n", stderr)
        exit(1)
    }
    i += 1
}

// MARK: - Main Logic

internalSensor = getInternalSensor()

guard let sensor = internalSensor else {
    fputs("Error: No ambient light sensor found\n", stderr)
    exit(1)
}

if isListening {
    // Listen mode: print lux values periodically
    Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
        if let lux = sensor.lux {
            let average = computeLuxWindowAverage(lux: lux)
            if isBare {
                print(String(format: "%.1f", average ?? lux))
            } else {
                print(String(format: "%.1f lux (avg: %.1f)", lux, average ?? lux))
            }
        } else {
            fputs("Error: Failed to read lux value\n", stderr)
        }
    }
    RunLoop.main.run()
} else {
    // Default mode: print current lux once and exit
    if let lux = sensor.lux {
        let average = computeLuxWindowAverage(lux: lux)
        print(String(format: "%.1f", average ?? lux))
        exit(0)
    } else {
        fputs("Error: Failed to read lux value\n", stderr)
        exit(1)
    }
}
