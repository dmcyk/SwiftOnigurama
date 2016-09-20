@_exported import Coniguruma
import Foundation

public func withUnsafeMutableFirstBufferPointer<T, Result>(to arg: inout [T], _ body:  (UnsafeMutablePointer<UnsafeMutablePointer<T>?>) throws -> Result) rethrows -> Result {
    return try withUnsafeMutablePointer(to: &arg[0]) { (first: UnsafeMutablePointer<T>?) -> Result in
        var m_first = first
        
        return try withUnsafeMutablePointer(to: &m_first) { (ptr: UnsafeMutablePointer<UnsafeMutablePointer<T>?>) -> Result in
            let m_ptr = ptr
            return try body(m_ptr)
        }
    }
}

extension String {
    public func withUCString<Result>(_ body: (UnsafePointer<UInt8>) throws -> Result) rethrows -> Result {
        return try withCString { ptr in
            return try ptr.withMemoryRebound(to: UInt8.self, capacity: characters.count) { uptr in
                return try body(uptr)
            }
        }
    }
}

public class Regex {
    public enum Encoding {
        case ascii, utf8
        
        var onigEncoding: OnigEncodingType {
            switch self {
            case .ascii:
                return OnigEncodingASCII
            case .utf8:
                return OnigEncodingUTF8
            }
        }
    }
    
    public struct OnigErr: Swift.Error {
        let info: OnigErrorInfo?
        let code: Int32
        let message: String
    }
    
    public enum Error: Swift.Error {
        case region, descriptive(err: OnigErr)
    }
    
    var regex: OnigRegex? = OnigRegex.allocate(capacity: 1)

    
    public init(pattern: String, encoding: Encoding = .ascii) throws {
        var r: Int32 = 0
        var info = OnigErrorInfo()
        
        pattern.withUCString { cStr in
            var onigEncoding = encoding.onigEncoding
            r = onig_new(&regex, cStr, cStr.advanced(by: pattern.characters.count), ONIG_OPTION_DEFAULT, &onigEncoding, OnigDefaultSyntax, &info)
        }
        if r != ONIG_NORMAL {
            let message = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(ONIG_MAX_ERROR_MESSAGE_LEN))
            _ = onig_error_code_to_str_info(message, r, &info);
            let strMessage = String(cString: message)
            message.deinitialize()
            message.deallocate(capacity: Int(ONIG_MAX_ERROR_MESSAGE_LEN))
            throw Error.descriptive(err: OnigErr(info: info, code: r, message: strMessage))
        }
        
    }
    
    deinit {
        onig_free(regex)
        onig_end()
    }
    
    public func test(_ str: String) throws -> Bool {
        guard let reg = onig_region_new() else {
            throw Error.region
        }
        
        var start: UnsafePointer<UInt8>! = nil
        var range: UnsafePointer<UInt8>! = nil
        var end: UnsafePointer<UInt8>! = nil
        
        let res: Int32 = str.withUCString { ptr in
            start = ptr
            end = ptr.advanced(by: str.characters.count)
            range = end
            return onig_search(regex!, ptr, end, start, range, reg, ONIG_OPTION_NONE)

        }
        
        onig_region_free(reg, 1)
        if res >= 0 {
            return true
        } else if res == ONIG_MISMATCH {
            return false
        } else {
            let message = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(ONIG_MAX_ERROR_MESSAGE_LEN))
            _ = onig_error_code_to_str_raw(message, res);
            throw Error.descriptive(err: OnigErr(info: nil, code: res, message: String(cString: message)))
        }
    }
    
    public func firstMatch(_ str: String) throws -> Range<String.Index>? {
        guard let reg = onig_region_new() else {
            throw Error.region
        }
        
        var start: UnsafePointer<UInt8>! = nil
        var range: UnsafePointer<UInt8>! = nil
        var end: UnsafePointer<UInt8>! = nil
        
        let res: Int32 = str.withUCString { ptr in
            start = ptr
            end = ptr.advanced(by: str.characters.count)
            range = end
            return onig_search(regex!, ptr, end, start, range, reg, ONIG_OPTION_NONE)
            
        }
        defer {
            onig_region_free(reg, 1)
        }
        if res >= 0 {
            return Range<String.Index>(uncheckedBounds:(str.index(str.startIndex, offsetBy: String.IndexDistance(reg.pointee.beg.pointee)), str.index(str.startIndex, offsetBy: String.IndexDistance(reg.pointee.end.pointee))))
        } else if res == ONIG_MISMATCH {
            return nil
        } else {
            let message = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(ONIG_MAX_ERROR_MESSAGE_LEN))
            _ = onig_error_code_to_str_raw(message, res)
            let strMessage = String(cString: message)
            message.deinitialize()
            message.deallocate(capacity: Int(ONIG_MAX_ERROR_MESSAGE_LEN))
            throw Error.descriptive(err: OnigErr(info: nil, code: res, message: strMessage))
        }
    }
    
    public func replace(_ str: inout String, with: String) throws {
        guard let reg = onig_region_new() else {
            throw Error.region
        }
        var start: UnsafePointer<UInt8>! = nil
        var range: UnsafePointer<UInt8>! = nil
        var end: UnsafePointer<UInt8>! = nil
        var res: Int32 = 0
        
        while res >= 0 {
            res = str.withUCString { ptr in
                start = ptr
                end = ptr.advanced(by: str.characters.count)
                range = end
                return onig_search(regex!, ptr, end, start, range, reg, ONIG_OPTION_NONE)
            }
            if res >= 0 {
                
                str.replaceSubrange(Range<String.Index>(uncheckedBounds:(str.index(str.startIndex, offsetBy: String.IndexDistance(reg.pointee.beg.pointee)), str.index(str.startIndex, offsetBy: String.IndexDistance(reg.pointee.end.pointee)))), with: with)
            }
        }
        onig_region_free(reg, 1)
    }
}

