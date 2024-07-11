//
//  CandidateCommandView.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/05/24.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import Foundation
import SwiftUI

struct CandidateCommandView: View {
    @ObservedObject var commandManager = CommandManager.shared
    @State private var expandedGroups: Set<String> = []
    @State private var selectedCommand: Command? = nil
    @State private var showCommandDescription: Bool = false
    @State private var commandDescription: String = ""
    @State private var showAddCommandView: Bool = false
    
    var isSinglePage: Bool

    var body: some View {
        VStack {
            List {
                ForEach(groupedCommands, id: \.key) { group, commands in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedGroups.contains(group) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedGroups.insert(group)
                                } else {
                                    expandedGroups.remove(group)
                                }
                            }
                        )
                    ) {
                        ForEach(commands) { command in
                            commandRow(command: command)
                        }
                        .onDelete { indices in
                            removeCommands(at: indices, from: group)
                        }
                    } label: {
                        Text(group)
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            if isSinglePage {
                HStack {
                    Button(action: {
                        commandManager.showAllCommands()
                    }) {
                        Text("Show All Commands")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        showAddCommandView = true
                    }) {
                        Text("Add Command")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .sheet(isPresented: $showAddCommandView) {
                        AddCommandView { newCommand in
                            commandManager.addCommand(newCommand)
                        }
                    }
                }
                .padding(.bottom)
            }
        }
        .onAppear {
//            print("Commands loaded: \(commandManager.commands.count)")
        }
        .alert(isPresented: $showCommandDescription) {
            Alert(title: Text("Command Description"), message: Text(commandDescription), dismissButton: .default(Text("OK")))
        }
    }

    var groupedCommands: [(key: String, value: [Command])] {
        let filteredCommands = commandManager.commands.filter { !$0.displayName.isEmpty }
        let grouped = Dictionary(grouping: filteredCommands, by: { $0.group ?? "Ungrouped" })
        return grouped.filter { !$0.value.isEmpty }
                      .sorted { $0.key < $1.key }
    }

    private func commandRow(command: Command) -> some View {
        HStack {
            Text(command.displayName)
                .font(.subheadline)
                .contextMenu {
                    Button(action: {
                        showCommandDescription(command: command)
                    }) {
                        Text("Show Description")
                        Image(systemName: "info.circle")
                    }
                }
            Spacer()
        }
        .padding(.vertical, 4)
        .onTapGesture {
            handleCommandTap(command: command)
        }
        .onLongPressGesture {
            showCommandDescription(command: command)
        }
    }

    private func handleCommandTap(command: Command) {
        selectedCommand = command
        print("Selected command: \(command.displayName)")
        guard let current = TerminalViewController.visibleTerminal else { return }
        current.send(txt: command.displayName + "\n")
    }
    
    private func showCommandDescription(command: Command) {
        commandDescription = command.description
        showCommandDescription = true
    }
    
    private func removeCommands(at offsets: IndexSet, from group: String) {
        let commandsInGroup = commandManager.commands.filter { $0.group == group }
        for index in offsets {
            if let command = commandsInGroup[safe: index] {
                if let commandIndex = commandManager.commands.firstIndex(where: { $0.id == command.id }) {
                    commandManager.commands.remove(at: commandIndex)
                }
            }
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
