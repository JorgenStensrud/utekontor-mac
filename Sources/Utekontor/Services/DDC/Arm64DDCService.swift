import CoreFoundation
import Darwin
import Foundation
import IOKit

@MainActor
final class Arm64DDCService {
    private static let chipAddress: UInt32 = 0x37
    private static let dataAddress: UInt32 = 0x51
    private static let luminanceVCP: UInt8 = 0x10
    /// DDC/CI needs a pause between the read request and fetching the reply.
    private static let replyDelayMicroseconds: useconds_t = 40_000
    /// Probing blocks the main actor ~40ms per candidate, so a dead monitor
    /// must not be allowed to re-trigger discovery on every slider write.
    private static let discoveryRetryMinInterval: TimeInterval = 1.0

    private var service: IOAVService?
    private var lastDiscoveryAttemptAt: Date?

    func connect() -> Bool {
        if service != nil {
            return true
        }
        if let lastDiscoveryAttemptAt,
           Date().timeIntervalSince(lastDiscoveryAttemptAt) < Self.discoveryRetryMinInterval {
            return false
        }
        lastDiscoveryAttemptAt = Date()
        service = Self.discoverService()
        return service != nil
    }

    /// Drops the cached service so the next write reconnects. A cached
    /// IOAVService goes stale when the monitor is unplugged, the Mac sleeps,
    /// or a dock is reconnected — writes against it fail silently forever.
    /// Also clears the discovery rate limit: this is called on genuine
    /// display-topology changes, where an immediate reconnect is wanted.
    func invalidate() {
        service = nil
        lastDiscoveryAttemptAt = nil
    }

    @discardableResult
    func writeBrightness(normalized: Float) -> Bool {
        let value = UInt16(round(max(0, min(1, normalized)) * 100))
        guard connect(), let service else {
            return false
        }
        if Self.write(service: service, vcp: Self.luminanceVCP, value: value) {
            return true
        }
        // Stale handle (sleep/dock/unplug without a topology event) — drop it
        // and reconnect once. Deliberately not invalidate(): connect()'s rate
        // limit must survive so a dead monitor can't re-run blocking
        // discovery on every coalesced slider write.
        self.service = nil
        guard connect(), let fresh = self.service else {
            return false
        }
        return Self.write(service: fresh, vcp: Self.luminanceVCP, value: value)
    }

    private static func write(service: IOAVService, vcp: UInt8, value: UInt16) -> Bool {
        let payload: [UInt8] = [vcp, UInt8(value >> 8), UInt8(value & 0xFF)]
        var packet: [UInt8] = [UInt8(0x80 | (payload.count + 1)), UInt8(payload.count)] + payload + [0]
        packet[packet.count - 1] = checksum(seed: chipAddress << 1 ^ dataAddress, data: packet.dropLast())
        let packetCount = UInt32(packet.count)

        return packet.withUnsafeMutableBytes { bytes in
            guard let function = PrivateDisplayAPIs.writeI2C else {
                return false
            }
            return function(
                service,
                chipAddress,
                dataAddress,
                bytes.baseAddress,
                packetCount
            ) == kIOReturnSuccess
        }
    }

    /// Reads the current luminance over DDC/CI. Used to probe whether a
    /// candidate service actually has a responsive monitor behind it.
    private static func readLuminance(service: IOAVService) -> UInt16? {
        guard let writeFn = PrivateDisplayAPIs.writeI2C, let readFn = PrivateDisplayAPIs.readI2C else {
            return nil
        }
        var request: [UInt8] = [0x82, 0x01, luminanceVCP, 0]
        request[request.count - 1] = checksum(seed: chipAddress << 1 ^ dataAddress, data: request.dropLast())
        let requestCount = UInt32(request.count)
        let wrote = request.withUnsafeMutableBytes { bytes in
            writeFn(service, chipAddress, dataAddress, bytes.baseAddress, requestCount) == kIOReturnSuccess
        }
        guard wrote else { return nil }

        usleep(replyDelayMicroseconds)
        var reply = [UInt8](repeating: 0, count: 11)
        let replyCount = UInt32(reply.count)
        let read = reply.withUnsafeMutableBytes { bytes in
            readFn(service, chipAddress, dataAddress, bytes.baseAddress, replyCount) == kIOReturnSuccess
        }
        // reply[4] echoes the VCP code when the monitor answered the request.
        guard read, reply[4] == luminanceVCP else { return nil }
        return UInt16(reply[8]) << 8 | UInt16(reply[9])
    }

    private static func discoverService() -> IOAVService? {
        let candidates = externalServices()
        // A single candidate needs no probing — and each probe blocks the
        // main actor ~40ms waiting for the DDC reply.
        guard candidates.count > 1 else {
            return candidates.first
        }
        // Multi-port Macs can expose several "External" proxies where only the
        // one with a monitor attached answers DDC. Probe before committing.
        if let responding = candidates.first(where: { readLuminance(service: $0) != nil }) {
            return responding
        }
        // Some monitors are write-only over DDC; fall back to the first proxy.
        return candidates.first
    }

    private static func externalServices() -> [IOAVService] {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        guard root != 0 else { return [] }
        defer { IOObjectRelease(root) }

        var iterator = io_iterator_t()
        let status = IORegistryEntryCreateIterator(
            root,
            "IOService",
            IOOptionBits(kIORegistryIterateRecursively),
            &iterator
        )
        guard status == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var services: [IOAVService] = []
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            guard registryEntryName(entry) == "DCPAVServiceProxy" else { continue }
            guard stringProperty(entry, key: "Location") == "External" else { continue }
            guard let function = PrivateDisplayAPIs.createIOAVServiceWithService else { continue }
            guard let unmanaged = function(kCFAllocatorDefault, entry) else { continue }
            services.append(unmanaged.takeRetainedValue())
        }

        return services
    }

    private static func checksum<S: Sequence>(seed: UInt32, data: S) -> UInt8 where S.Element == UInt8 {
        data.reduce(UInt8(truncatingIfNeeded: seed)) { partial, byte in
            partial ^ byte
        }
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
