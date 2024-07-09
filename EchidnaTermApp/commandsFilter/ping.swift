import Foundation
import SwiftUI

let log = FileHandle(forWritingAtPath: "/dev/null")!

func processPingOutput(_ input: String) {
//    print("ping input=", input)
//    @ObservedObject var viewModel = TargetTreeViewModel()
    let viewModel = TargetTreeViewModel.shared
    let linesReader = LinesReader(string: input)
//    for target in targets(linesReader) {
    for target in targets(linesReader) {
//        print("ParserOutput*** ",target)
        //        print("remote\t\(target)")
//        viewModel.addTarget(value: target, toParent: 0)
        viewModel.addTarget(key:"host", value: target, toParent: 0)
    }
}

func extractInfo(inputString: String) -> String? {
    if let hostMatch = inputString.range(of: #"from ([a-zA-Z0-9\-_]+) \((\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\)"#, options: .regularExpression) {
        let host = inputString[hostMatch].split(separator: " ")[1]
        return String(host)
    }

    if let ipMatch = inputString.range(of: #"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"#, options: .regularExpression) {
        let ip = inputString[ipMatch]
        return String(ip)
    }

    return nil
}

private func targets(_ linesReader: LinesReader) -> [String] {
    var result = [String]()
    for line in linesReader {
        if line.contains("Unreachable") {
            continue
        }
        if !line.contains("icmp_seq") {
            continue
        }
        if let host = extractInfo(inputString: line) {
            result.append(host)
            return result
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
