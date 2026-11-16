// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

import CoreFoundation

class TestPropertyListSerialization : XCTestCase {
    func test_BasicConstruction() {
        let dict = NSMutableDictionary(capacity: 0)
//        dict["foo"] = "bar"
        var data: Data? = nil
        do {
            data = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
        } catch {
            
        }
        XCTAssertNotNil(data)
        XCTAssertEqual(data!.count, 42, "empty dictionary should be 42 bytes")
    }
    
    func test_decodeData() {
        var decoded: Any?
        var fmt = PropertyListSerialization.PropertyListFormat.binary
        let path = testBundle().url(forResource: "Test", withExtension: "plist")
        let data = try! Data(contentsOf: path!)
        do {
            decoded = try withUnsafeMutablePointer(to: &fmt) { (format: UnsafeMutablePointer<PropertyListSerialization.PropertyListFormat>) -> Any in
                return try PropertyListSerialization.propertyList(from: data, options: [], format: format)
            }
        } catch {
            
        }

        XCTAssertNotNil(decoded)
        let dict = decoded as! Dictionary<String, Any>
        XCTAssertEqual(dict.count, 3)
        let val = dict["Foo"]
        XCTAssertNotNil(val)
        if let str = val as? String {
            XCTAssertEqual(str, "Bar")
        } else {
            XCTFail("value stored is not a string")
        }
    }

    func test_decodeStream() {
        var decoded: Any?
        var fmt = PropertyListSerialization.PropertyListFormat.binary
        let path = testBundle().url(forResource: "Test", withExtension: "plist")
        let stream = InputStream(url: path!)!
        stream.open()
        do {
            decoded = try withUnsafeMutablePointer(to: &fmt) { (format: UnsafeMutablePointer<PropertyListSerialization.PropertyListFormat>) -> Any in
                return try PropertyListSerialization.propertyList(with: stream, options: [], format: format)
            }
        } catch {

        }

        XCTAssertNotNil(decoded)
        let dict = decoded as! Dictionary<String, Any>
        XCTAssertEqual(dict.count, 3)
        let val = dict["Foo"]
        XCTAssertNotNil(val)
        if let str = val as? String {
            XCTAssertEqual(str, "Bar")
        } else {
            XCTFail("value stored is not a string")
        }
    }

    func test_decodeEmptyData() {
        XCTAssertThrowsError(try PropertyListSerialization.propertyList(from: Data(), format: nil)) { error in
            let nserror = error as NSError
            XCTAssertEqual(nserror.domain, NSCocoaErrorDomain)
            XCTAssertEqual(CocoaError(_nsError: nserror).code, .propertyListReadCorrupt)
            XCTAssertEqual(nserror.userInfo[NSDebugDescriptionErrorKey] as? String, "Cannot parse a NULL or zero-length data")
        }
    }
    
    func test_decodeOverflowUnicodeString() throws {
        var native = "ФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФ"
        let ns = native.withCString {
            NSString(utf8String: $0)!
        }
        do {
            var buffer = Array<UInt8>(repeating: 1, count: native.utf8.count)
            buffer.withUnsafeMutableBufferPointer { bufferPtr in
                var used: CFIndex = 0
                CFStringGetBytes(unsafeBitCast(ns, to: CFString.self), CFRangeMake(0, ns.length), CFStringBuiltInEncodings.UTF8.rawValue, 0xF, false, bufferPtr.baseAddress!, 10, &used)
                XCTAssertEqual(used, 10)
            }
            for i in 10 ..< buffer.count {
                XCTAssertEqual(buffer[i], 1)
            }
        }
        do {
            var buffer = Array<UInt16>(repeating: 1, count: native.utf8.count)
            buffer.withUnsafeMutableBufferPointer { bufferPtr in
                var used: CFIndex = 0
                CFStringGetBytes(unsafeBitCast(ns, to: CFString.self), CFRangeMake(0, ns.length), CFStringBuiltInEncodings.UTF16.rawValue, 0xF, false, bufferPtr.baseAddress!, 10, &used)
                XCTAssertEqual(used, 10)
            }
            for i in 10 ..< buffer.count {
                XCTAssertEqual(buffer[i], 1)
            }
        }
    }

    func test_decodeLargeXMLDataValue() throws {
        // Decode a <data> element whose body is large enough to push the parser past the 16 MB mark.
        let byteCount = 20 * 1024 * 1024 + 7
        var raw = Data(count: byteCount)
        raw.withUnsafeMutableBytes { (buf: UnsafeMutableRawBufferPointer) in
            let p = buf.bindMemory(to: UInt8.self)
            var x: UInt32 = 0x12345678
            for i in 0 ..< byteCount {
                x = x &* 1664525 &+ 1013904223
                p[i] = UInt8(truncatingIfNeeded: x >> 24)
            }
        }
        let base64 = raw.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<plist version=\"1.0\">\n<data>\n\(base64)\n</data>\n</plist>\n"
        let data = xml.data(using: .utf8)!
        let decoded = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let outData = try XCTUnwrap(decoded as? Data)
        XCTAssertEqual(outData.count, byteCount)
        XCTAssertEqual(outData, raw)
    }

    func test_keyedArchiveRoundTrip() throws {
        let root: NSDictionary = ["key": "value", "number": NSNumber(value: 7)]
        let archive = try NSKeyedArchiver.archivedData(withRootObject: root, requiringSecureCoding: false)
        for format in [PropertyListSerialization.PropertyListFormat.binary, .xml] {
            // Read the archive as a property list and write it again, so that the keyed archiver UIDs go through both directions.
            let plist = try PropertyListSerialization.propertyList(from: archive, options: [], format: nil)
            let rewritten = try PropertyListSerialization.data(fromPropertyList: plist, format: format, options: 0)
            let unarchived = try XCTUnwrap(NSKeyedUnarchiver.unarchiveObject(with: rewritten) as? NSDictionary)
            XCTAssertEqual(unarchived, root)
        }
    }

    func test_valuesCastToObjects() throws {
        let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist version=\"1.0\"><dict><key>string</key><string>text</string><key>integer</key><integer>42</integer><key>real</key><real>1.5</real><key>bool</key><true/><key>array</key><array><string>a</string></array></dict></plist>"
        let plist = try PropertyListSerialization.propertyList(from: Data(xml.utf8), options: [], format: nil)
        let dictionary = try XCTUnwrap(plist as? NSDictionary)
        XCTAssertEqual(dictionary["string"] as? NSString, "text")
        XCTAssertEqual((dictionary["integer"] as? NSNumber)?.intValue, 42)
        XCTAssertEqual((dictionary["real"] as? NSNumber)?.doubleValue, 1.5)
        XCTAssertEqual((dictionary["bool"] as? NSNumber)?.boolValue, true)
        XCTAssertEqual((dictionary["array"] as? NSArray)?.count, 1)
    }
}
