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
                    } label: {
                        Text(group)
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())

            /*            if let selectedCommand = selectedCommand {
                Text("Selected command: \(selectedCommand.displayName)")
                    .padding()
            }*/
        }
        .onAppear {
            print("Commands loaded: \(commandManager.commands.count)")
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
                    /*
                    Button(action: {
                        UIPasteboard.general.string = command.displayName
                    }) {
                        Text("Copy")
                        Image(systemName: "doc.on.doc")
//                        showCommandDescription(command: command)
                    }
                     */
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
        print("current=", current)
        current.send(txt: command.displayName + "\n")
    }
    
    private func showCommandDescription(command: Command) {
        commandDescription = command.description
        showCommandDescription = true
    }
}
