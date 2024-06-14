//
//  TargetDetailView.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/06/04.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//
import SwiftUI

struct TargetDetailView: View {
    let target: Target
    @ObservedObject var viewModel = TargetTreeViewModel.shared

    var body: some View {
        VStack {
            Text("Details for \(target.value)")
                .font(.headline)
                .padding()
            
            List {
                TargetTree(target: target)
            }
        }
        .onAppear {
            viewModel.loadJSON()
        }
    }
}

struct TargetTree: View {
    let target: Target
    @State private var isExpanded: Bool = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(target.children ?? [], id: \.self) { childId in
                if let child = targetMap[childId] {
                    TargetTree(target: child)
                }
            }
        } label: {
            Text(target.value)
                .padding()
                .foregroundColor(target.shouldHighlight ? .yellow : .primary)
        }
    }
}

struct FilteredTargetTreeView: View {
    let rootTarget: Target

    var body: some View {
        TargetTreeView(rootTargets: [rootTarget], initialExpandedNode: rootTarget)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }
}

/*
struct FilteredTargetTreeView: View {
    @ObservedObject var viewModel = TargetTreeViewModel.shared
    let rootTarget: Target
    @State private var selectedTarget: Target? = nil

    var body: some View {
        VStack {
            List([rootTarget], id: \.id, children: \.childrenTargets) { target in
                HStack {
                    Text(target.value)
                        .padding()
                        .foregroundColor(target.shouldHighlight ? .yellow : .primary)
                        .background(selectedTarget?.id == target.id ? Color.blue.opacity(0.3) : Color.clear)
                        .cornerRadius(8)
                        .onTapGesture {
                            selectedTarget = target
                            handleTargetSelection(target)
                        }
                    
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .onAppear {
            viewModel.loadJSON()
        }
    }
    
    private func handleTargetSelection(_ target: Target) {
        print("Selected target: \(target.value)")
        let commandManager = CommandManager.shared
        commandManager.updateCandidateCommand(target: target)
    }
}
*/
