import CoreFoundation
import IOKit

@MainActor
final class Arm64DDCService {
    private static let chipAddress: UInt32 = 0x37
    private static let dataAddress: UInt32 = 0x51

    private var service: IOAVService?

    func connect() -> Bool {
        if service != nil {
            return true
        }
        service = Self.firstExternalService()
        return service != nil
    }

    @discardableResult
    func writeBrightness(normalized: Float) -> Bool {
        guard connect(), let service else {
            return false
        }

        let value = UInt16(round(max(0, min(1, normalized)) * 100))
        let payload: [UInt8] = [0x10, UInt8(value >> 8), UInt8(value & 0xFF)]
        var packet: [UInt8] = [UInt8(0x80 | (payload.count + 1)), UInt8(payload.count)] + payload + [0]
        packet[packet.count - 1] = Self.checksum(seed: Self.chipAddress << 1 ^ Self.dataAddress, data: packet.dropLast())
        let packetCount = UInt32(packet.count)

        return packet.withUnsafeMutableBytes { bytes in
            guard let function = PrivateDisplayAPIs.writeI2C else {
                return false
            }
            return function(
                service,
                Self.chipAddress,
                Self.dataAddress,
                bytes.baseAddress,
                packetCount
            ) == kIOReturnSuccess
        }
    }

    private static func checksum<S: Sequence>(seed: UInt32, data: S) -> UInt8 where S.Element == UInt8 {
        data.reduce(UInt8(seed)) { partial, byte in
            partial ^ byte
        }
    }

    private static func firstExternalService() -> IOAVService? {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        guard root != 0 else { return nil }
        defer { IOObjectRelease(root) }

        var iterator = io_iterator_t()
        let status = IORegistryEntryCreateIterator(
            root,
            "IOService",
            IOOptionBits(kIORegistryIterateRecursively),
            &iterator
        )
        guard status == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            guard registryEntryName(entry) == "DCPAVServiceProxy" else { continue }
            guard stringProperty(entry, key: "Location") == "External" else { continue }
            guard let function = PrivateDisplayAPIs.createIOAVServiceWithService else { continue }
            guard let unmanaged = function(kCFAllocatorDefault, entry) else { continue }
            return unmanaged.takeRetainedValue()
        }

        return nil
    }

    private static func registryEntryName(_ entry: io_registry_entry_t) -> String? {
        let pointer = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
        defer { pointer.deallocate() }
        guard IORegistryEntryGetName(entry, pointer) == KERN_SUCCESS else {
            return nil
        }
        return String(cString: pointer)
    }

    private static func stringProperty(_ entry: io_registry_entry_t, key: String) -> String? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
    }
}
