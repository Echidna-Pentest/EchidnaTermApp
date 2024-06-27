//
//  whatweb.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/06/28.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import Foundation

/*
let inputString = """
http://metasploitable [200 OK] Apache[2.2.8], Country[RESERVED][ZZ], HTTPServer[Ubuntu Linux][Apache/2.2.8 (Ubuntu) DAV/2], IP[192.168.11.16], PHP[5.2.4-2ubuntu5.10], Title[Metasploitable2 - Linux], WebDAV[2], X-Powered-By[PHP/5.2.4-2ubuntu5.10]
"""
*/

func processWhatwebOutput(lines: String) {
    let viewModel = TargetTreeViewModel.shared
    guard lines.contains("[200 OK]") else {
        return
    }
//    print("processNiktoOutput lines=", lines)

    let results = extractHostnameAndRecords(from: lines)

    for result in results {
//        print("\(result.0)\t\(result.1)\t\(result.2)")
        viewModel.processInput("\(result.0)\t\(result.1)\twhatweb\t\(result.2)", key: "whatweb")
    }
}

func extractHostnameAndRecords(from input: String) -> [(String, Int, String)] {

    print("whatWeb input=", input)
    // Extract hostname
    var hostname = ""
    var port = 80
    if input.contains("http://") {
        hostname = input.components(separatedBy: "http://")[1].components(separatedBy: " ")[0]
        port = 80
    } else if input.contains("https://") {
        hostname = input.components(separatedBy: "https://")[1].components(separatedBy: " ")[0]
        port = 443
    }
    
    // Extract comma-separated records
    let recordString = input.components(separatedBy: "] ")[1]
    let records = recordString.components(separatedBy: ", ")
    
    return records.map { (hostname, port, $0) }
}

/*
let results = extractHostnameAndRecords(from: inputString)

for result in results {
    print("\(result.0)\t\(result.1)\t\(result.2)")
}
*/
