//
//  hydra.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/06/13.
//

import Foundation

let scanResultPattern = ".*\\[(\\S+)\\].*\\[(\\S+)\\].*host: (\\S+).*login: (\\S+).*password: (\\S+).*"

func processHydraOutput(_ input: String) -> [[String]] {
//    print("processHydraOutput")
    let viewModel = TargetTreeViewModel.shared
    var results = [[String]]()
    let lines = input.split(separator: "\n")
    let scanResultRegex = try! NSRegularExpression(pattern: scanResultPattern, options: [])

    for line in lines {
//        print("hydra: line=", line)
        if let match = scanResultRegex.firstMatch(in: String(line), options: [], range: NSRange(location: 0, length: line.count)) {
            let port = (line as NSString).substring(with: match.range(at: 1))
            let host = (line as NSString).substring(with: match.range(at: 3))
            let username = (line as NSString).substring(with: match.range(at: 4))
            let password = (line as NSString).substring(with: match.range(at: 5))
//            print("hydra: port=", port, " targetHostname=", host, " username=", username, " password=", password)
            viewModel.processInput("\(host)\t\(port)\tuser=\(username); pass=\(password)", key: "multiple")

/*            if let host = typeAddress(targetHostname) {
                results.append(host + ["port", port, "user", username])
                results.append(host + ["port", port, "user", username, "pass", password])
            }*/
        }
    }
    return results
}

func typeAddress(_ hostname: String) -> [String]? {
    // Implement your type_address logic here
    return ["host", hostname]
}

/*
func main() {
    let input = CommandLine.arguments.dropFirst().joined(separator: "\n")
    let results = parseHydraOutput(input)
    for result in results {
        print(result.joined(separator: "\t"))
    }
}

main()
*/
