import SwiftUI

struct TargetTreeView: View {
    @ObservedObject var viewModel = TargetTreeViewModel.shared
    @State private var selectedTarget: Target? = nil
    @State private var showingAddTargetSheet = false
    @State private var showingRemoveTargetAlert = false
    @State private var targetForAdd: Target? = nil
    @State private var targetForRemove: Target? = nil
    var rootTargets: [Target]?

    var body: some View {
        VStack {
            List(rootTargets ?? [viewModel.targets.first(where: { $0.id == 0 })].compactMap { $0 }, id: \.id, children: \.childrenTargets) { target in
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
                            handleAddTarget(target: target)
                        }) {
                            Image(systemName: "plus.circle")
                        }
                        .contentShape(Rectangle()) // Ensure entire button area is tappable

                        Button(action: {
                            handleRemoveTarget(target: target)
                        }) {
                            Image(systemName: "minus.circle")
                        }
                        .contentShape(Rectangle()) // Ensure entire button area is tappable
                    }
                    .buttonStyle(PlainButtonStyle()) // Prevent default button styling interference
                }
            }
            .onAppear {
                viewModel.loadJSON()
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
//        print("Selected target: \(target.value)")
        CommandManager.shared.updateCandidateCommand(target: target)
    }
    
    private func handleAddTarget(target: Target) {
//        print("Add button clicked for target: \(target.value)")
        targetForAdd = target
        showingAddTargetSheet = true
    }

    private func handleRemoveTarget(target: Target) {
//        print("Remove button clicked for target: \(target.value)")
        targetForRemove = target
        showingRemoveTargetAlert = true
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
