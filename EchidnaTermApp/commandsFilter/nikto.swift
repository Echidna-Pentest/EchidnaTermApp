//
//  nikto.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/06/19.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import Foundation

let SCAN_RESULTS = "^+"
let START_TIME = "Start Time:"
let TARGET_HOSTNAME = "Target Hostname:\\s*(\\S+)"
let TARGET_PORT = "Target Port:\\s*(\\S+)"

func processNiktoOutput(lines: String) {
    let viewModel = TargetTreeViewModel.shared
//    print("processNiktoOutput lines=", lines)
    let scanResults = parseScanResults(lines: lines)
    for result in scanResults {
//        print("\(result.host)\t\(result.port)\t\(result.result)")
//        viewModel.processInput("\(result.host)\t\(result.port)\t\(result.result)", key: "nikto")
        viewModel.processInput("\(result.host)\t\(result.port)\tnikto\t\(result.result)", key: "nikto")
    }
}

func parseScanResults(lines: String) -> [(host: String, port: String, result: String)] {
    var results: [(host: String, port: String, result: String)] = []
    var targetHostname = ""
    var targetPort = ""
    var startTimeEncountered = false
    var lineCounter = 0

    let lineArray = lines.components(separatedBy: .newlines)
    for line in lineArray {
        print("processNiktoOutput: line=", line)
        if startTimeEncountered {
            lineCounter += 1
            if lineCounter > 2, let _ = line.range(of: SCAN_RESULTS, options: .regularExpression) {
                results.append((host: targetHostname, port: targetPort, result: line))
            }
        } else if line.contains(START_TIME) {
            startTimeEncountered = true
            lineCounter = 1
        } else {
            if let hostname = extractMatch(for: TARGET_HOSTNAME, in: line) {
                targetHostname = hostname
            } else if let port = extractMatch(for: TARGET_PORT, in: line) {
                targetPort = port
            }
        }
    }

    return results
}

func extractMatch(for pattern: String, in line: String) -> String? {
    let regex = try? NSRegularExpression(pattern: pattern)
    let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
    if let result = regex?.firstMatch(in: line, options: [], range: nsRange),
       let range = Range(result.range(at: 1), in: line) {
        return String(line[range])
    }
    return nil
}

// Read from standard input
/*
if var allInput = readLine(strippingNewline: false) {
    while let line = readLine(strippingNewline: false) {
        allInput += line
    }
    processNiktoOutput(lines: allInput)
} else {
    print("Please provide input.")
}
*/
