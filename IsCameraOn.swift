import AVFoundation
import CoreMediaIO

// Borrowed from https://github.com/wouterdebie/onair/blob/master/Sources/onair/Camera.swift

if CommandLine.arguments.count >= 2, ["-h", "--help"].contains(CommandLine.arguments[1]) {
    print("Usage: \(CommandLine.arguments[0]) [-q (exits with non-zero status code if camera is not on)]")
    exit(0)
}

// MARK: - Camera

class Camera: CustomStringConvertible {
    init?(captureDevice: AVCaptureDevice) {
        guard let id = captureDevice.value(forKey: "_connectionID") as? CMIOObjectID else { return nil }
        self.captureDevice = captureDevice
        self.id = id

        // Figure out if this is a virtual (DAL) device or an actual hardware device.
        // It seems that DAL devices have kCMIODevicePropertyLatency, while normal
        // AVCaptureDevices don't.
        var latencyPA = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyLatency),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )
        var dataSize = UInt32(0)

        if CMIOObjectGetPropertyDataSize(id, &latencyPA, 0, nil, &dataSize) == OSStatus(kCMIOHardwareNoError) {
            isVirtual = true
        }
    }

    public var description: String { "\(captureDevice.manufacturer)/\(captureDevice.localizedName)" }

    var isVirtual = false

    func isOn() -> Bool {
        // Test if the device is on through some magic. If the pointee is > 0, the device is active.
        var (dataSize, dataUsed) = (UInt32(0), UInt32(0))
        guard CMIOObjectGetPropertyDataSize(id, &STATUS_PA, 0, nil, &dataSize) == OSStatus(kCMIOHardwareNoError), dataSize > 0,
              let data = malloc(Int(dataSize))
        else { return false }
        defer { free(data) }

        guard CMIOObjectGetPropertyData(id, &STATUS_PA, 0, nil, dataSize, &dataUsed, data) == OSStatus(kCMIOHardwareNoError) else { return false }
        return data.assumingMemoryBound(to: UInt8.self).pointee > 0
    }

    private var id: CMIOObjectID
    private var captureDevice: AVCaptureDevice
    private var STATUS_PA = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
    )
}

// USB webcams, Studio Display cameras and Continuity Camera count too, not only the built-in one
var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
if #available(macOS 14.0, *) {
    deviceTypes += [.external, .continuityCamera]
} else {
    deviceTypes += [.externalUnknown]
}

let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .unspecified)
let cameraInUse = discoverySession.devices.contains { Camera(captureDevice: $0)?.isOn() ?? false }

guard CommandLine.arguments.contains("-q") else {
    print(cameraInUse)
    exit(0)
}

exit(cameraInUse ? 0 : 1)
