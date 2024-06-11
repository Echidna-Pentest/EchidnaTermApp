//
//  nmap.swift
//  SwiftTermApp
//
//  Created by Terada Yu on 2024/05/20.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import Foundation

let HOST = try! NSRegularExpression(pattern: "^Nmap scan report for (\\S+)(\\([^\\)]*\\))?")

func processNmapOutput(input: String) {
    let viewModel = TargetTreeViewModel.shared
    let lines = input.components(separatedBy: .newlines)
//    print("Nmap lines=", lines)
    var lineIterator = lines.makeIterator()
    if let host = findHost(lines: &lineIterator) {
        skipToPortHeader(lines: &lineIterator)
        while let portData = ports(lines: &lineIterator) {
            let portDetails = portData.0
            let details = portData.1

            for portDetail in portDetails {
                print("Nmap Host + Port", (host + portDetail).joined(separator: "\t"))
                viewModel.processInput((host + portDetail).joined(separator: "\t"))

                var cleanedPortDetail = portDetail
                if let versionIndex = portDetail.firstIndex(of: "version"), versionIndex + 1 < portDetail.count {
                    cleanedPortDetail.remove(at: versionIndex + 1) // Remove the element after "version"
                    cleanedPortDetail.remove(at: versionIndex) // Remove "version"
                }
                
                for detail in details {
                    print("Nmap Host + Port portDetail=", portDetail, " detail=", detail)
//                    viewModel.processInput((host + portDetail + detail).joined(separator: "\t"))
                    viewModel.processInput((host + cleanedPortDetail + detail).joined(separator: "\t"))
                }
            }
        }
    }
}

func findHost(lines: inout IndexingIterator<[String]>) -> [String]? {
    while let line = lines.next() {
        let range = NSRange(location: 0, length: line.utf16.count)
        if let match = HOST.firstMatch(in: line, options: [], range: range) {
            if let hostRange = Range(match.range(at: 1), in: line) {
                let host = String(line[hostRange])
                if match.range(at: 2).location != NSNotFound, let addressRange = Range(match.range(at: 2), in: line) {
                    return [host, String(line[addressRange])]
                } else {
                    return [host]
                }
            }
        }
    }
    return ["host", "unknown"]
}

func skipToPortHeader(lines: inout IndexingIterator<[String]>) {
    let headerPattern = try! NSRegularExpression(pattern: "PORT\\s+STATE\\s+SERVICE")
    while let line = lines.next() {
        let range = NSRange(location: 0, length: line.utf16.count)
        if headerPattern.firstMatch(in: line, options: [], range: range) != nil {
            break
        }
    }
}

func ports(lines: inout IndexingIterator<[String]>) -> ([[String]], [[String]])? {
    var result = [[String]]()
    var details = [[String]]()

    while let line = lines.next() {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLine.isEmpty {
            continue
        }

        let firstComponent = trimmedLine.split(separator: " ", maxSplits: 1).first
        if let firstComponent = firstComponent, firstComponent.contains("/") {
            let components = trimmedLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard components.count >= 3 else { continue }

            let port = String(components[0].split(separator: "/")[0])
            let state = String(components[1])
            let name = String(components[2].split(separator: " ")[0])
            
            if state == "closed" {
                break
            }
            
            if components.count > 2 {
                let version = components[2].split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                if version.count > 1 {
                    result.append([port, "service: " + name, "version", String(version[1])])
                } else {
                    result.append([port, "service: " + name])
                }
            } else {
                result.append([port, "service: " + name])
            }
        } else if trimmedLine.hasPrefix("|") || trimmedLine.hasPrefix("Service Info:") {
            details.append(["detail", trimmedLine])
        }
    }
    
    return result.isEmpty ? nil : (result, details)
}

func portDetails(lines: inout IndexingIterator<[String]>) -> [[String]] {
    var details = [[String]]()
    
    while let line = lines.next() {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedLine.isEmpty {
            continue
        }
        
        if trimmedLine.hasPrefix("|") || trimmedLine.hasPrefix("Service Info:") {
            details.append(["detail", trimmedLine])
        } else {
            break
        }
    }
    
    return details
}


func portDetailsOld(lines: inout IndexingIterator<[String]>) -> [[String]] {
    var result = [[String]]()
    while let line = lines.next() {
        if line.hasPrefix("|") {
            for vulner in vulners(lines: &lines) {
                result.append(vulner)
            }
            for detail in vulnDetails(lines: &lines) {
                result.append(detail)
            }
        } else if line.prefix(1).rangeOfCharacter(from: .decimalDigits) == nil {
//            break
            continue
        } else {
            if line.contains("OS details:") {
                if let match = line.range(of: "OS details:\\s*(Linux|Window)", options: .regularExpression) {
                    let osDetail = String(line[match])
                    result.append(["OS", osDetail])
                }
            } else if line == "\n" {
                continue
            } else {
                result.append(["info", line.trimmingCharacters(in: .whitespaces)])
            }
        }
    }
    return result
}

func vulnDetails(lines: inout IndexingIterator<[String]>) -> [[String]] {
    var result = [[String]]()
    while let line = lines.next() {
        if line.hasPrefix("|_") {
            let parts = line.dropFirst(2).split(separator: ":")
            if parts.count > 1 {
                result.append([String(parts[0]) + ":", String(parts[1])])
            }
        } else if line.hasPrefix("| ") {
            let name = String(line.dropFirst(2).trimmingCharacters(in: .whitespaces))
            while let nextLine = lines.next(), nextLine.hasPrefix("| ") {
                result.append([name, String(nextLine.dropFirst(2).trimmingCharacters(in: .whitespaces))])
            }
        }
    }
    return result
}

func vulners(lines: inout IndexingIterator<[String]>) -> [[String]] {
    var result = [[String]]()
    if let line = lines.next(), line.hasPrefix("| vulners:") {
        while let nextLine = lines.next(), nextLine.hasPrefix("|  ") {
            let platform = String(nextLine.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines).dropLast())
            result.append(["platform", platform, "vulner", nextLine.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
    }
    return result
}


// Helper extension to check if an optional is not nil
extension Optional {
    var isNotNil: Bool {
        return self != nil
    }
}
