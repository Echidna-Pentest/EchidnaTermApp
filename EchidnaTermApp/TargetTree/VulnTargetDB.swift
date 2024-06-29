//
//  VulnTargetDB.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/05/29.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import Foundation

class VulnerabilityDatabase {
    private let criticalScanFile = "vulnTargetDB.json"
    private var criticalScanDB: [[String: Any]] = []

    init() {
        setup()
    }

    private func setup() {
        /*
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirectory.appendingPathComponent(criticalScanFile)
         */

        /*
        let projectDirectory = "/Users/yu/work/EchidnaApp/release/EchidnaTermApp/EchidnaTermApp"
        let filePath = "\(projectDirectory)/vulnTargetDB.json"
        let fileURL = URL(fileURLWithPath: filePath)

        
        do {
            let data = try Data(contentsOf: fileURL)
            if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                criticalScanDB = jsonArray
            }
//            print("vulnTargetDB criticalScanDB=", criticalScanDB)
        } catch {
            print("Error reading critical scan database: \(error)")
        }
         */
        
        if let fileURL = Bundle.main.url(forResource: "vulnTargetDB", withExtension: "json") {
            do {
                let data = try Data(contentsOf: fileURL)
                if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    criticalScanDB = jsonArray
                }
                //            print("vulnTargetDB criticalScanDB=", criticalScanDB)
            } catch {
                print("Error reading critical scan database: \(error)")
            }
        }
    }

    func getValues(for key: String) -> [Any] {
        return criticalScanDB.compactMap { $0[key] }
    }

    func searchValue(for targetValue: String, obj: [[String: Any]]? = nil, machineName: String? = nil) -> [String: Any]? {
        let database = obj ?? criticalScanDB
        print("searchValue= datbase=", database)
//        print("searchValue=", database)
        for dict in database {
            for (prop, value) in dict {
                if let nestedDict = value as? [String: Any] {
                    if var result = searchValue(for: targetValue, obj: [nestedDict], machineName: dict["machine_name"] as? String) {
                        if let machineName = machineName {
                            result["machine_name"] = machineName
                        }
                        return result
                    }
                } else if let stringValue = value as? String, stringValue.contains(targetValue) {
                    return dict
                }
            }
        }
        return nil
    }
}
