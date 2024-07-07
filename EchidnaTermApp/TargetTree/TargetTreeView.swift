import SwiftUI

struct TargetTreeView: View {
    @StateObject private var viewModel = TargetTreeViewModel.shared
    @State private var selectedTarget: Target? = nil
    @State private var showingAddTargetSheet = false
    @State private var showingRemoveTargetAlert = false
    @State private var showingEditTargetSheet = false
    @State private var targetForAdd: Target? = targetMap[0]
    @State private var targetForRemove: Target? = nil
    @State private var targetForEdit: Target? = targetMap[0]
    @State private var expandedNodes: Set<Int> = []  // Set to keep track of expanded nodes
    @State private var searchText: String = ""  // State to hold the search text
    var rootTargets: [Target]?
    var initialExpandedNode: Target?  // Initial node to be expanded
    var initialSearchText: String = ""  // Initial search text
    
    var body: some View {
        VStack {
            // Search bar
            HStack {
                TextField("Search...", text: $searchText, onCommit: {
                    search()
                })
                .padding(6)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .frame(height: 30)  // Adjust the height here
                .padding(.horizontal)
            }
            .padding(.top, 10)

            List {
                ForEach(rootTargets ?? [viewModel.targets.first(where: { $0.id == 0 })].compactMap { $0 }, id: \.id) { target in
                    ExpandableRow(
                        target: target,
                        expandedNodes: $expandedNodes,
                        selectedTarget: $selectedTarget,
                        handleAddTarget: handleAddTarget,
                        handleRemoveTarget: handleRemoveTarget,
                        handleTargetSelection: handleTargetSelection,
                        handleEditTarget: handleEditTarget
                    )
                }
            }
            .onAppear {
                // Expand the initial node on first appearance
                if let initialTarget = initialExpandedNode {
                    expandedNodes.insert(initialTarget.id)
                    handleTargetSelection(initialTarget)
                } else if let firstTarget = viewModel.targets.first(where: { $0.id == 0 }) {
                    expandedNodes.insert(firstTarget.id)
                    handleTargetSelection(firstTarget)
                }
                // Perform the initial search if provided
                if !initialSearchText.isEmpty {
                    searchText = initialSearchText
                    search()
                }
            }
            .sheet(isPresented: $showingAddTargetSheet) {
                if let targetForAdd = targetForAdd {
                    AddTargetSheet(isPresented: $showingAddTargetSheet, parentTarget: targetForAdd) { key, value in
                        viewModel.addTarget(key: key, value: value, toParent: targetForAdd.id)
                    }
                }
            }
            .sheet(isPresented: $showingEditTargetSheet) {
                if let targetForEdit = targetForEdit {
                    EditTargetSheet(isPresented: $showingEditTargetSheet, target: targetForEdit) { newValue in
                        viewModel.updateTarget(targetForEdit, with: newValue)
                    }
                }
            }
            .alert(isPresented: $showingRemoveTargetAlert) {
                if let targetForRemove = targetForRemove {
                    if targetForRemove.id == 0 {
                        return Alert(
                            title: Text("Error"),
                            message: Text("Root Target cannot be removed."),
                            dismissButton: .default(Text("OK"))
                        )
                    } else {
                        return Alert(
                            title: Text("Confirm Removal"),
                            message: Text("Is it ok to remove \(targetForRemove.value)?"),
                            primaryButton: .destructive(Text("Yes")) {
                                viewModel.removeTarget(target: targetForRemove)
                            },
                            secondaryButton: .cancel()
                        )
                    }
                } else {
                    return Alert(title: Text("Error"))
                }
            }
        }
    }

    private func search() {
        viewModel.searchTarget(with: searchText)
        if let result = viewModel.searchResult {
            expandToTarget(result)
        }
    }

    private func expandToTarget(_ target: Target) {
        var currentTarget: Target? = target
        while let parent = currentTarget?.parent, let parentTarget = targetMap[parent] {
            expandedNodes.insert(parentTarget.id)
            currentTarget = parentTarget
        }
        expandedNodes.insert(target.id)
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
    
    private func handleEditTarget(target: Target) {
        targetForEdit = target
        showingEditTargetSheet = true
    }
}

struct ExpandableRow: View {
    var target: Target
    @Binding var expandedNodes: Set<Int>
    @Binding var selectedTarget: Target?
    var handleAddTarget: (Target) -> Void
    var handleRemoveTarget: (Target) -> Void
    var handleTargetSelection: (Target) -> Void
    var handleEditTarget: (Target) -> Void
    
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
                    .onLongPressGesture {
                        handleEditTarget(target)
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
                        handleTargetSelection: handleTargetSelection,
                        handleEditTarget: handleEditTarget
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

struct EditTargetSheet: View {
    @Binding var isPresented: Bool
    var target: Target
    var onUpdate: (String) -> Void
    
    @State private var newValue: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Target")) {
                    TextField("Value", text: $newValue)
                        .onAppear {
                            newValue = target.value
                        }
                }
            }
            .navigationBarTitle("Edit Target", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                isPresented = false
            }, trailing: Button("Save") {
                onUpdate(newValue)
                isPresented = false
            })
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
