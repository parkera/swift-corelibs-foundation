// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

@_implementationOnly import CoreFoundation

extension PropertyListSerialization {
    public typealias WriteOptions = Int

    public class func propertyList(_ plist: Any, isValidFor format: PropertyListFormat) -> Bool {
        let fmt = CFPropertyListFormat(rawValue: CFIndex(format.rawValue))!
        let plistObj = __SwiftValue.store(plist)
        return CFPropertyListIsValid(plistObj, fmt)
    }

    public class func data(fromPropertyList plist: Any, format: PropertyListFormat, options opt: WriteOptions) throws -> Data {
        var error: Unmanaged<CFError>? = nil
        let result = withUnsafeMutablePointer(to: &error) { (outErr: UnsafeMutablePointer<Unmanaged<CFError>?>) -> CFData? in
            let fmt = CFPropertyListFormat(rawValue: CFIndex(format.rawValue))!
            let options = CFOptionFlags(opt)
            let plistObj = __SwiftValue.store(plist)
            let d = CFPropertyListCreateData(kCFAllocatorSystemDefault, plistObj, fmt, options, outErr)
            return d?.takeRetainedValue()
        }
        if let res = result {
            return res._swiftObject
        } else {
            throw error!.takeRetainedValue()._nsObject
        }
    }

#if !os(WASI)
    internal class func propertyList(with stream: CFReadStream, options opt: ReadOptions, format: UnsafeMutablePointer<PropertyListFormat>?) throws -> Any {
        try propertyList(from: try _readAll(from: stream), options: opt, format: format)
    }

    /// Reads `stream` to its end. The caller opens the stream.
    private class func _readAll(from stream: CFReadStream) throws -> Data {
        let bufferSize = 64 * 1024
        var data = Data()
        try withUnsafeTemporaryAllocation(of: UInt8.self, capacity: bufferSize) { buffer in
            while true {
                let count = CFReadStreamRead(stream, buffer.baseAddress!, bufferSize)
                if count < 0 {
                    throw CocoaError(.propertyListReadStream, userInfo: [NSDebugDescriptionErrorKey : "The stream could not be read."])
                }
                if count == 0 {
                    return
                }
                data.append(buffer.baseAddress!, count: count)
            }
        }
        return data
    }

    public class func propertyList(with stream: InputStream, options opt: ReadOptions = [], format: UnsafeMutablePointer<PropertyListFormat>?) throws -> Any {
        return try propertyList(with: stream._stream, options: opt, format: format)
    }
#endif
}
