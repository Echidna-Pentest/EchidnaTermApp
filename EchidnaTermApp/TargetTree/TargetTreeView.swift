import SwiftUI

struct TargetTreeView: View {
    @ObservedObject var viewModel = TargetTreeViewModel.shared
    @State private var selectedTarget: Target? = nil
    @State private var showingAddTargetSheet = false
    @State private var targetForAdd: Target? = nil
    var rootTargets: [Target]? = nil

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
                            targetForAdd = target
                            showingAddTargetSheet = true
                        }) {
                            Image(systemName: "plus.circle")
                        }
                        .sheet(isPresented: $showingAddTargetSheet) {
                            if let targetForAdd = targetForAdd {
                                AddTargetView(isPresented: $showingAddTargetSheet, parentTarget: targetForAdd, onAdd: { key, value in
                                    viewModel.addTarget(key: key, value: value, toParent: targetForAdd.id)
                                })
                            }
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadJSON()
            }
        }
    }
    
    private func handleTargetSelection(_ target: Target) {
        print("Selected target: \(target.value)")
        let commandManager = CommandManager.shared
        commandManager.updateCandidateCommand(target: target)
    }
}


struct AddTargetView: View {
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
