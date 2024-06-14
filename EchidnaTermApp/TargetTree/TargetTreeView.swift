import SwiftUI

struct TargetTreeView: View {
    @ObservedObject var viewModel = TargetTreeViewModel.shared
    @State private var selectedTarget: Target? = nil
    @State private var showingAddTargetSheet = false
    @State private var showingRemoveTargetAlert = false
    @State private var targetForAdd: Target? = nil
    @State private var targetForRemove: Target? = nil
    @State private var expandedNodes: Set<Int> = []  // Set to keep track of expanded nodes
    var rootTargets: [Target]?
    var initialExpandedNode: Target?  // Initial node to be expanded

    var body: some View {
        VStack {
            List {
                ForEach(rootTargets ?? [viewModel.targets.first(where: { $0.id == 0 })].compactMap { $0 }, id: \.id) { target in
                    ExpandableRow(
                        target: target,
                        expandedNodes: $expandedNodes,
                        selectedTarget: $selectedTarget,
                        handleAddTarget: handleAddTarget,
                        handleRemoveTarget: handleRemoveTarget,
                        handleTargetSelection: handleTargetSelection
                    )
                }
            }
            .onAppear {
                viewModel.loadJSON()
                // Expand the initial node on first appearance
                if let initialTarget = initialExpandedNode {
                    expandedNodes.insert(initialTarget.id)
                    handleTargetSelection(initialTarget)
                } else if let firstTarget = viewModel.targets.first(where: { $0.id == 0 }) {
                    expandedNodes.insert(firstTarget.id)
                    handleTargetSelection(firstTarget)
                }
            }
            .sheet(isPresented: $showingAddTargetSheet) {
                if let targetForAdd = targetForAdd {
                    AddTargetSheet(isPresented: $showingAddTargetSheet, parentTarget: targetForAdd) { key, value in
                        viewModel.addTarget(key: key, value: value, toParent: targetForAdd.id)
                    }
                }
            }
            .alert(isPresented: $showingRemoveTargetAlert) {
                if let targetForRemove = targetForRemove {
                    return Alert(
                        title: Text("Confirm Removal"),
                        message: Text("Is it ok to remove \(targetForRemove.value)?"),
                        primaryButton: .destructive(Text("Yes")) {
                            viewModel.removeTarget(target: targetForRemove)
                        },
                        secondaryButton: .cancel()
                    )
                } else {
                    return Alert(title: Text("Error"))
                }
            }
        }
    }
    
    private func handleTargetSelection(_ target: Target) {
        // Call the command update function when a target is selected
        CommandManager.shared.updateCandidateCommand(target: target)
    }
    
    private func handleAddTarget(target: Target) {
        targetForAdd = target
        showingAddTargetSheet = true
    }

    private func handleRemoveTarget(target: Target) {
        targetForRemove = target
        showingRemoveTargetAlert = true
    }
}

struct ExpandableRow: View {
    var target: Target
    @Binding var expandedNodes: Set<Int>
    @Binding var selectedTarget: Target?
    var handleAddTarget: (Target) -> Void
    var handleRemoveTarget: (Target) -> Void
    var handleTargetSelection: (Target) -> Void
    
    var body: some View {
        VStack {
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

                HStack(spacing: 10) {
                    Button(action: {
                        handleAddTarget(target)
                    }) {
                        Image(systemName: "plus.circle")
                    }
                    .contentShape(Rectangle()) // Ensure entire button area is tappable

                    Button(action: {
                        handleRemoveTarget(target)
                    }) {
                        Image(systemName: "minus.circle")
                    }
                    .contentShape(Rectangle()) // Ensure entire button area is tappable

                    // Only show expand/collapse button if there are children
                    if target.childrenTargets != nil {
                        Button(action: {
                            toggleExpand()
                        }) {
                            Image(systemName: expandedNodes.contains(target.id) ? "chevron.down" : "chevron.right")
                        }
                        .contentShape(Rectangle()) // Ensure entire button area is tappable
                    }
                }
                .buttonStyle(PlainButtonStyle()) // Prevent default button styling interference
            }
            
            if expandedNodes.contains(target.id) {
                ForEach(target.childrenTargets ?? [], id: \.id) { child in
                    ExpandableRow(
                        target: child,
                        expandedNodes: $expandedNodes,
                        selectedTarget: $selectedTarget,
                        handleAddTarget: handleAddTarget,
                        handleRemoveTarget: handleRemoveTarget,
                        handleTargetSelection: handleTargetSelection
                    )
                    .padding(.leading, 20)
                }
            }
        }
    }
    
    private func toggleExpand() {
        if expandedNodes.contains(target.id) {
            expandedNodes.remove(target.id)
        } else {
            expandedNodes.insert(target.id)
        }
    }
}

struct AddTargetSheet: View {
    @Binding var isPresented: Bool
    var parentTarget: Target
    @State private var newKey = ""
    @State private var newValue = ""
    var onAdd: (String, String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Target Details")) {
                    TextField("Key", text: $newKey)
                    TextField("Value", text: $newValue)
                }
            }
            .navigationBarTitle("Add New Target", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                isPresented = false
            }, trailing: Button("Add") {
                onAdd(newKey, newValue)
                isPresented = false
            })
        }
    }
}
