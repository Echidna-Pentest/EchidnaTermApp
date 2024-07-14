//
//  CandidateCommand.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/05/20.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import SwiftUI

class Command: Identifiable, ObservableObject, Equatable {
    let id = UUID()
    @Published var template: String
    @Published var displayName: String
    var patterns: [String]
    var condition: [String]
    var group: String?
    var description: String

    init(template: String, patterns: [String], condition: [String], group: String? = nil, description: String) {
        self.template = template
        self.displayName = template
        self.patterns = patterns
        self.condition = condition
        self.group = group
        self.description = description
    }
    
    static func == (lhs: Command, rhs: Command) -> Bool {
        return lhs.id == rhs.id
    }
}

class CommandManager: ObservableObject {
    static let shared = CommandManager()
    @Published var commands: [Command] = []
    var hostname = ""
    var isInitialShellEstablished = false
    
    init() {
        copyCommandsFileIfNeeded()
        loadCommandsFromFile()
    }
    
    func copyCommandsFileIfNeeded() {
        let fileManager = FileManager.default
        let documentDirectory = getDocumentsDirectory()
        let destinationURL = documentDirectory.appendingPathComponent("commands.txt")
        
        if let sourceURL = Bundle.main.url(forResource: "commands", withExtension: "txt") {
            print("commands.txt found in bundle at \(sourceURL.path)")
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                print("commands.txt successfully copied to \(destinationURL.path)")
            } catch {
                print("Failed to copy commands.txt: \(error)")
            }
        } else {
            print("commands.txt not found in bundle")
        }
    }

    
    func loadCommandsFromFile() {
        let localFileURL = getDocumentsDirectory().appendingPathComponent("commands.txt")
        let myCommandsFileURL = getDocumentsDirectory().appendingPathComponent("mycommands.txt")
        
        var allCommands: [Command] = []
        
        if FileManager.default.fileExists(atPath: localFileURL.path) {
            allCommands.append(contentsOf: loadCommands(from: localFileURL))
        }
        
        if FileManager.default.fileExists(atPath: myCommandsFileURL.path) {
            allCommands.append(contentsOf: loadCommands(from: myCommandsFileURL))
        }
        
        commands = allCommands
    }
    
    func loadCommands(from fileURL: URL) -> [Command] {
        var loadedCommands: [Command] = []
        
        do {
            let fileContents = try String(contentsOf: fileURL)
            let entries = fileContents.components(separatedBy: "[Echidna]").dropFirst()
            
            for entry in entries {
                let lines = entry.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                var patterns: [String] = []
                var description = ""
                var templates: [String] = []
                var conditions: [String] = []
                var group: String?
                
                for line in lines {
                    if line.hasPrefix("pattern:") {
                        let pattern = line.replacingOccurrences(of: "pattern:", with: "").trimmingCharacters(in: .whitespaces)
                        patterns.append(pattern)
                    } else if line.hasPrefix("description:") {
                        description = line.replacingOccurrences(of: "description:", with: "").trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("template:") {
                        let template = line.replacingOccurrences(of: "template:", with: "").trimmingCharacters(in: .whitespaces)
                        templates.append(template)
                    } else if line.hasPrefix("condition:") {
                        let conditionString = line.replacingOccurrences(of: "condition:", with: "").trimmingCharacters(in: .whitespaces)
                        if let data = conditionString.data(using: .utf8) {
                            if let array = try? JSONSerialization.jsonObject(with: data, options: []) as? [String] {
                                conditions = array
                            }
                        }
                    } else if line.hasPrefix("group:") {
                        group = line.replacingOccurrences(of: "group:", with: "").trimmingCharacters(in: .whitespaces)
                    }
                }
                
                for template in templates {
                    let command = Command(template: template, patterns: patterns, condition: conditions, group: group, description: description)
                    loadedCommands.append(command)
                }
            }
        } catch {
            print("Error reading file: \(error)")
        }
        
        return loadedCommands
    }
    
    func saveCommandToFile(_ command: Command, to fileURL: URL) {
        var fileContents = ""
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                fileContents = try String(contentsOf: fileURL)
            } catch {
                print("Failed to read existing file: \(error)")
            }
        }
        
        fileContents += "[Echidna]\n"
        for pattern in command.patterns {
            fileContents += "pattern: \(pattern)\n"
        }
        fileContents += "description: \(command.description)\n"
        fileContents += "template: \(command.template)\n"
        if !command.condition.isEmpty {
            if let conditionData = try? JSONSerialization.data(withJSONObject: command.condition, options: []),
               let conditionString = String(data: conditionData, encoding: .utf8) {
                fileContents += "condition: \(conditionString)\n"
            }
        }
        if let group = command.group {
            fileContents += "group: \(group)\n"
        }
        fileContents += "[end]\n\n"
        
        do {
            try fileContents.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write to file: \(error)")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func setHostname(hostname: String) {
        self.hostname = hostname
    }

    func setInitialShellEstablishedFlag(isInitialShellEstablished: Bool) {
        self.isInitialShellEstablished = isInitialShellEstablished
//        objectWillChange.send()
//        print("setInitialShellEstablishedFlag=", self.isInitialShellEstablished)
    }

    
    func updateCandidateCommand(target: Target) {
        for command in commands {
            if command.condition.isEmpty || shouldDisplayCommand(command: command, for: target) {
                command.displayName = command.template
                replaceTargetInCommand(target: target, in: &command.displayName)
                objectWillChange.send()
            } else {
                command.displayName = ""
            }
        }
    }
    
    func showAllCommands() {
        for command in commands {
            command.displayName = command.template
        }
        objectWillChange.send()
    }
    
    func addCommand(_ command: Command) {
        commands.append(command)
        let fileURL = getDocumentsDirectory().appendingPathComponent("mycommands.txt")
        saveCommandToFile(command, to: fileURL)
        objectWillChange.send()
    }
    
    private func shouldDisplayCommand(command: Command, for target: Target) -> Bool {
        var currentTarget: Target? = target
//        print("shouldDisplayCommand: command=", command.condition)
        
        if command.condition.contains("isInitialShellEstablished") {
//            print("shouldDisplayCommand: CommandManager.shared.isInitialShellEstablished=", CommandManager.shared.isInitialShellEstablished)
            return CommandManager.shared.isInitialShellEstablished
        }
        
        while let target = currentTarget {
            for keyword in command.condition {
                if target.value.contains(keyword) {
                    return true
                }
                if target.key.contains(keyword) {
                    return true
                }
            }
            if let parentId = target.parent {
                currentTarget = targetMap[parentId]
            } else {
                currentTarget = nil
            }
        }

        return false
    }
    
    private func replaceTargetInCommand(target: Target, in displayName: inout String) {
        var currentTarget: Target? = target
        
        if let range = displayName.range(of: "{localip}") {
            displayName.replaceSubrange(range, with: self.hostname)
        }

        while let target = currentTarget {
            if target.key == "multiple" {
                // Parse the target.value to check for key1=value1; key2=value2 format
                let keyValuePairs = target.value.components(separatedBy: "; ")
                var replacements: [String: String] = [:]
                for pair in keyValuePairs {
                    let keyValue = pair.components(separatedBy: "=")
                    if keyValue.count == 2 {
                        let key = keyValue[0].trimmingCharacters(in: .whitespaces)
                        let value = keyValue[1].trimmingCharacters(in: .whitespaces)
                        replacements[key] = value
                    }
                }
                // Replace keys in displayName with their corresponding values
                for (key, value) in replacements {
                    if let range = displayName.range(of: "{\(key)}") {
                        displayName.replaceSubrange(range, with: value)
                    }
                }
            } else {
                if let range = displayName.range(of: "{\(target.key)}") {
                    displayName.replaceSubrange(range, with: target.value)
                }
            }
            
            if let parentId = target.parent {
                currentTarget = targetMap[parentId]
            } else {
                currentTarget = nil
            }
        }
    }
    
    func getAllPatterns() -> [String] {
        var patternSet = Set<String>()
        for command in commands {
            patternSet.formUnion(command.patterns)
        }
        return Array(patternSet)
    }
}
