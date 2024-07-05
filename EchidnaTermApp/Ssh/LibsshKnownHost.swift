//
//  LibsshKnownHost.swift
//  EchidnaTermApp
//
//  Created by Miguel de Icaza on 1/20/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation
@_implementationOnly import CSSH

public enum KnownHostStatus {
    /// hosts and keys match.
    case match
    /// something prevented the check to be made
    case failure
    ///  host was found, but the keys didn't match
    case keyMismatch
    /// no host match was found
    case notFound
}

class LibsshKnownHost {
    func check(hostName: String, port: Int32, key: [Int8]) -> (status: KnownHostStatus, key: String?) { // (status: KnownHostStatus, knownHost: libssh2_knownhost?) {

        var ptr: UnsafeMutablePointer<libssh2_knownhost>? = UnsafeMutablePointer<libssh2_knownhost>.allocate(capacity: 1)
        var kcopy = key
        
        let r = libssh2_knownhost_checkp(khHandle, hostName, port, &kcopy, key.count, LIBSSH2_KNOWNHOST_TYPE_PLAIN | LIBSSH2_KNOWNHOST_KEYENC_RAW, &ptr)
        defer {
            //ptr?.deallocate()
        }
        switch r {
            
        case LIBSSH2_KNOWNHOST_CHECK_FAILURE:
            return (.failure, nil)
        case LIBSSH2_KNOWNHOST_CHECK_MATCH:
            let x: libssh2_knownhost = ptr?.pointee ?? libssh2_knownhost()
            let keyStr = String(cString: x.key)
            return (.match, keyStr)
        case LIBSSH2_KNOWNHOST_CHECK_MISMATCH:
            let x: libssh2_knownhost = ptr?.pointee ?? libssh2_knownhost()
            let keyStr = String(cString: x.key)
            return (.keyMismatch, keyStr)
        case LIBSSH2_KNOWNHOST_CHECK_NOTFOUND:
            return (.notFound, nil)
        default:
            return (.failure, nil)
        }
    }
    
    var khHandle: OpaquePointer
    weak var sessionActor: SessionActor!
    
    init (sessionActor: SessionActor, knownHost: OpaquePointer){
        self.sessionActor = sessionActor
        self.khHandle = knownHost
    }
    
    deinit {
        libssh2_knownhost_free (khHandle)
    }
    
    // returns nil on success, otherwise an error description
    func readFile (filename: String) async -> String? {
        return await sessionActor.readFile (knownHost: self, filename: filename)
    }
    
    // returns nil on success, otherwise an error description
    func writeFile (filename: String) async -> String? {
        return await sessionActor.writeFile (knownHost: self, filename: filename)
    }
    
    /// Returns nil on success, otherwise a string describing the error
    func add(hostname: String, port: Int32? = nil, key: [Int8], keyType: String, comment: String) async -> String? {

        let fullhostname: String
        if let p = port {
            fullhostname = "[\(hostname)]:\(p)"
        } else {
            fullhostname = hostname
        }

        let keyTypeCode: Int32
        switch keyType {
        case "ssh-rsa":
            keyTypeCode = LIBSSH2_KNOWNHOST_KEY_SSHRSA
        case "ssh-dss":
            keyTypeCode = LIBSSH2_KNOWNHOST_KEY_SSHDSS
        case "ecdsa-sha2-nistp256":
            keyTypeCode = LIBSSH2_KNOWNHOST_KEY_ECDSA_256
        case "ecdsa-sha2-nistp384":
            keyTypeCode = LIBSSH2_KNOWNHOST_KEY_ECDSA_384
        case "ecdsa-sha2-nistp521":
            keyTypeCode = LIBSSH2_KNOWNHOST_KEY_ECDSA_521
        case "ssh-ed25519", "ed25519":
            keyTypeCode = LIBSSH2_KNOWNHOST_KEY_ED25519
        default:
            return "knownHost.add: the provided key type is \(keyType) which is not currently supported"
        }

        return await sessionActor.add (knownHost: self, fullhostname: fullhostname, key: key, keyTypeCode: keyTypeCode, comment: comment)
    }
}
