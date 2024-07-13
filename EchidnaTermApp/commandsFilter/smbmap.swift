//
//  smbmap.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/05/19.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//
import Foundation
let viewModel = TargetTreeViewModel.shared

func processSmbmapOutput(_ output: String) {
    let reader = LineReader(string: output)
//    print("processSmbmapOutput      ", output)
    for target in targets(reader: reader) {
//        print("ParserOutput***      \(target.0)\t\(target.1)\t\(target.2)")
//        viewModel.processInput("\(target.0)\t\(target.1)\t\(target.2)")
        viewModel.processInput("\(target.0)\t\(target.1)\t\(target.2)", key: "SMBDrive")
    }
}

func findHost(lines: LineReader) -> (String, String, Int)? {
    let HEADER = try! NSRegularExpression(pattern: "\\[\\+\\] IP: (\\S+):(\\S+)\\s+Name: (\\S+)", options: [])

    while let line = lines.nextLine() {
        if let match = HEADER.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
            let ip = (line as NSString).substring(with: match.range(at: 1))
            let portString = (line as NSString).substring(with: match.range(at: 2))
            let host = (line as NSString).substring(with: match.range(at: 3))
            
            let port = Int(portString) ?? 445
            _ = lines.nextLine() // skip 2 lines since line after header is no useful data
            _ = lines.nextLine()
            return (ip, host, port)
        }
    }
    return nil
}

func targets(reader: LineReader) -> [(String, String, String)] {
    var result = [(String, String, String)]()
    while true {
        guard let (ip, host, port) = findHost(lines: reader) else { break }
        viewModel.processInput("\(host)\t\(port)", metadata: ["ipaddress": ip])

        while let line = reader.nextLine() {
            if line == "\n" { break }
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty || trimmedLine.allSatisfy({ $0 == "-" || $0 == " " || $0 == "\t" }) {
                continue
            }
            if !line.contains("NO ACCESS") {
                let scandetails = line.split(separator: "\t", omittingEmptySubsequences: false)
                if scandetails.count > 3 {
                    let details1 = String(scandetails[1].trimmingCharacters(in: .whitespacesAndNewlines))
                    let details2 = "\tPermissions: \(scandetails[2].trimmingCharacters(in: .whitespacesAndNewlines))"
//                    print("detail2=", details2)
                    let details3 = "\tComment: \(scandetails[3].trimmingCharacters(in: .whitespacesAndNewlines))"
                    result.append((host, "\(port)", "\(details1)\(details2)"))
                    result.append((host, "\(port)", "\(details1)\(details3)"))
                }
            }
        }
    }
    return result
}

class LineReader {
    let lines: [String]
    var currentIndex: Int
    
    init(string: String) {
        self.lines = string.components(separatedBy: .newlines)
        self.currentIndex = 0
    }
    
    func nextLine() -> String? {
        guard currentIndex < lines.count else { return nil }
        let line = lines[currentIndex]
        currentIndex += 1
        return line
    }
}
