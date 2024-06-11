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
    var lineIterator = lines.makeIterator()
    if let host = findHost(lines: &lineIterator) {
        skipToPortHeader(lines: &lineIterator)
        while let portData = ports(lines: &lineIterator) {
            let portDetails = portData.0
            let versionInfo = portData.1
            let details = portData.2

            print("Nmap Host + Port", (host + portDetails).joined(separator: "\t"))
            viewModel.processInput((host + portDetails).joined(separator: "\t"))

            // Version Information
            if !versionInfo.isEmpty {
                print("Nmap Host + Port", (host + portDetails + versionInfo).joined(separator: "\t"))
                viewModel.processInput((host + portDetails + versionInfo).joined(separator: "\t"))
            }

            for detail in details {
                print("Nmap Host + Port", (host + portDetails + detail).joined(separator: "\t"))
                viewModel.processInput((host + portDetails + detail).joined(separator: "\t"))
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

func ports(lines: inout IndexingIterator<[String]>) -> ([String], [String], [[String]])? {
    var result = [String]()
    var versionInfo = [String]()
    var details = [[String]]()

    while let line = lines.next() {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedLine.isEmpty {
            continue
        }

        // ポートの新しいエントリの開始を検出
        let firstComponent = trimmedLine.split(separator: " ", maxSplits: 1).first
        if firstComponent?.rangeOfCharacter(from: .decimalDigits) != nil {
            // 以前のポートの詳細がある場合は戻る
            if !result.isEmpty {
                return (result, versionInfo, details)
            }

            let components = trimmedLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard components.count >= 3 else { continue }

            let service = String(components[0].split(separator: "/")[0])
            let state = String(components[1])
            let name = String(components[2].split(separator: " ")[0])
            
            if state == "closed" {
                break
            }
            
            result = [service, "service: " + name]
            
            if components.count > 2 {
                let version = components[2].split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                if version.count > 1 {
                    versionInfo = ["version", String(version[1])]
                }
            }
        } else if trimmedLine.hasPrefix("|") || trimmedLine.hasPrefix("Service Info:") {
            details.append(["detail", trimmedLine])
        }
    }

    return (result, versionInfo, details).0.isEmpty ? nil : (result, versionInfo, details)
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
