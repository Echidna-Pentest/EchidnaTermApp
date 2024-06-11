//
//  CandidateCommand.swift
//  SwiftTermApp
//
//  Created by Terada Yu on 2024/05/20.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import SwiftUI

class Command: Identifiable, ObservableObject {
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
}

class CommandManager: ObservableObject {
    static let shared = CommandManager()
    @Published var commands: [Command] = []
    var hostname = ""
    
    init() {
        loadCommandsFromFile()
    }
    
    func loadCommandsFromFile() {
        guard let fileURL = Bundle.main.url(forResource: "commands", withExtension: "txt") else {
            print("commands.txt not found")
            return
        }
        
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
                    commands.append(command)
                    print("Loaded command: \(command)")
                }
            }
        } catch {
            print("Error reading commands.txt: \(error)")
        }
    }
    
    func setHostname(hostname: String){
        self.hostname = hostname
        print("sethostname=", self.hostname)
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
    
    private func shouldDisplayCommand(command: Command, for target: Target) -> Bool {
        for keyword in command.condition {
            if target.value.contains(keyword) {
                print("keyword=", keyword, "  target.value=", target.value)
                return true
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
            if let range = displayName.range(of: "{\(target.key)}") {
                displayName.replaceSubrange(range, with: target.value)
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
