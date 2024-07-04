//
//  smbVersionScan.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/07/04.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import Foundation

func processSmbVersionScanOutput(lines: String) {
    
/*
    let input = """
    [*] 192.168.11.16:445     - SMB Detected (versions:1) (preferred dialect:) (signatures:optional)
    [*] 192.168.11.16:445     -   Host could not be identified: Unix (Samba 3.0.20-Debian)
    [*] metasploitable:       - Scanned 1 of 1 hosts (100% complete)
    [*] Auxiliary module execution completed
    """
 */

    var hostName = ""
    var results: [String] = []
    
    // Define the regular expression pattern
    let ipPattern = "([0-9]{1,3}\\.){3}[0-9]{1,3}$"
    let ipRegex = try! NSRegularExpression(pattern: ipPattern)
//    print("processSmbVersionScanOutput: lines=", lines)

    // Split input into lines
    let lines = lines.components(separatedBy: "\n")

    for line in lines {
//        print("processSmbVersionScanOutput: line=", line)
        // Extract the hostname from lines containing "Scanned 1 of 1 hosts"
        if line.contains("Scanned 1 of 1 hosts") {
            if let range = line.range(of: " - Scanned 1 of 1 hosts") {
                hostName = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove "[*]" from the hostname
                hostName = hostName.replacingOccurrences(of: "[*]", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                // Set hostname if it contains ":"
                if hostName.contains(":") {
                    hostName = String(hostName.split(separator: ":")[0])
                }
                // Determine if it is an IP address using regex
                /*
                let hostNameRange = NSRange(location: 0, length: hostName.utf16.count)
                if ipRegex.firstMatch(in: hostName, options: [], range: hostNameRange) != nil {
                    print("IP address detected: \(hostName)")
                } else {
                    print("Hostname detected: \(hostName)")
                }
                 */
                // Update existing results with the hostname
                results = results.map { $0.replacingOccurrences(of: "IP_PLACEHOLDER", with: hostName) }
            }
        } else if line.contains(":") && line.contains("-") {
            // Extract IP address, port, and SMB information
            let components = line.components(separatedBy: " - ")
            if components.count > 1 {
                let addressPart = components[0].replacingOccurrences(of: "[*] ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let smbInfo = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Separate IP address and port
                let addressComponents = addressPart.split(separator: ":")
                if addressComponents.count == 2 {
                    let port = addressComponents[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !hostName.isEmpty {
                        results.append("\(hostName)\t\(port)\t\(smbInfo)")
                    } else {
                        results.append("IP_PLACEHOLDER\t\(port)\t\(smbInfo)")
                    }
                }
            }
        }
    }
    
    // Output the results
    let viewModel = TargetTreeViewModel.shared
    // Process the results
    for result in results {
        let elements = result.split(separator: "\t")
        if elements.count == 3 {
            let host = elements[0]
            let port = elements[1]
            let info = elements[2]
            // Call the function with the extracted elements
            viewModel.processInput("\(host)\t\(port)\tversion\t\(info)", key: "version")
        }
    }
}

