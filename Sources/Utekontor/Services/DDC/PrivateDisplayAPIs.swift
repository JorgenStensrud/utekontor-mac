import CoreFoundation
import CoreGraphics
import Darwin
import IOKit

typealias IOAVService = AnyObject

@MainActor
enum PrivateDisplayAPIs {
    typealias CreateIOAVServiceFn = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<AnyObject>?
    typealias WriteI2CFn = @convention(c) (IOAVService, UInt32, UInt32, UnsafeMutableRawPointer?, UInt32) -> IOReturn
    typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let displayServicesHandle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    )

    private static let ioKitHandle = dlopen(
        "/System/Library/Frameworks/IOKit.framework/IOKit",
        RTLD_LAZY
    )

    private static func load<T>(_ name: String, handle: UnsafeMutableRawPointer?) -> T? {
        guard let symbol = dlsym(handle, name) else {
            return nil
        }
        return unsafeBitCast(symbol, to: T.self)
    }

    static let createIOAVServiceWithService: CreateIOAVServiceFn? = load(
        "IOAVServiceCreateWithService",
        handle: ioKitHandle
    )

    static let writeI2C: WriteI2CFn? = load(
        "IOAVServiceWriteI2C",
        handle: ioKitHandle
    )

    static let getBrightness: GetBrightnessFn? = load(
        "DisplayServicesGetBrightness",
        handle: displayServicesHandle
    )

    static let setBrightness: SetBrightnessFn? = load(
        "DisplayServicesSetBrightness",
        handle: displayServicesHandle
    )
}
