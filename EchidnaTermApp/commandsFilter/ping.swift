import Foundation
import SwiftUI

let log = FileHandle(forWritingAtPath: "/dev/null")!

func processPingOutput(_ input: String) {
    let linesReader = LinesReader(string: input)
    _ = targets(linesReader)
}

func extractInfo(inputString: String) -> String? {
    let viewModel = TargetTreeViewModel.shared
    if let hostMatch = inputString.range(of: #"from ([a-zA-Z0-9\-_]+) \((\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\)"#, options: .regularExpression) {
        let parts = inputString[hostMatch].split(separator: " ")
        let host = String(parts[1])
        let ip = parts[2].trimmingCharacters(in: CharacterSet(charactersIn: "()"))
//        print("host=", host, " ip=", ip)
        viewModel.processInput(host, metadata: ["ipaddress": ip])
        return host
    } else if let ipMatch = inputString.range(of: #"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"#, options: .regularExpression) {
        let ip = String(inputString[ipMatch])
        viewModel.addTarget(key: "host", value: ip, toParent: 0)
        return ip
    }
    return nil
}

private func targets(_ linesReader: LinesReader) -> [String] {
    var result = [String]()
    for line in linesReader {
        if line.contains("Unreachable") || !line.contains("icmp_seq") {
            continue
        }
        if let host = extractInfo(inputString: line) {
            result.append(host)
        }
    }
    return result
}

private class LinesReader: Sequence, IteratorProtocol {
    var lines: [String]
    var currentIndex = 0

    init(string: String) {
        self.lines = string.components(separatedBy: "\n")
    }

    func next() -> String? {
        if currentIndex >= lines.count {
            return nil
        }
        let line = lines[currentIndex]
        currentIndex += 1
        return line
    }
}
