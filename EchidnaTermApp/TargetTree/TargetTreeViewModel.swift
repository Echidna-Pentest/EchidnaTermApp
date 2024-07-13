import SwiftUI

var targetMap = [Int: Target]()

class TargetTreeViewModel: ObservableObject {
    static let shared = TargetTreeViewModel()
    @Published var targets: [Target] = []
    @Published var searchResult: Target? = nil
    
    init() {
        let initialTarget = Target(id: 0, key: "Network", value: "Target Network", parent: -1, children: [])
        targets.append(initialTarget)
        targetMap[0] = initialTarget
        loadJSON()
    }

    
    func loadJSON() {
        print("loadJSON")
//        if let url = Bundle.main.url(forResource: "targets", withExtension: "json") {
        let url = getDocumentsDirectory().appendingPathComponent("targets.json")
        /*
        let projectDirectory = "/Users/yu/work/EchidnaApp/release/EchidnaTermApp/EchidnaTermApp/TargetTree"
        let filePath = "\(projectDirectory)/targets.json"
        let url = URL(fileURLWithPath: filePath)
         */
            do {
//                print("loadJson url=", url)
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                var targets = try decoder.decode([Target].self, from: data)
                print("loadJSON targets=", targets)
                targets.sort { $0.id < $1.id }
                self.targets = buildTree(targets: targets)
            } catch {
                print("Error loading JSON: \(error)")
            }

//        }
    }
    
    /*
    // for dubugging load json from local
    func loadJSON() {
        print("loadJSON")
        /*
        if let url = Bundle.main.url(forResource: "targets", withExtension: "json") {
        let url = getDocumentsDirectory().appendingPathComponent("targets.json")
         */
        let projectDirectory = "/Users/yu/work/EchidnaApp/release/EchidnaTermApp/EchidnaTermApp/TargetTree"
        let filePath = "\(projectDirectory)/targets.json"
        let url = URL(fileURLWithPath: filePath)
        do {
            print("loadJson url=", url)
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            var targets = try decoder.decode([Target].self, from: data)
            print("loadJSON targets=", targets)
            targets.sort { $0.id < $1.id }
            self.targets = buildTree(targets: targets)
        } catch {
            print("Error loading JSON: \(error)")
        }
    }
     */

    func buildTree(targets: [Target]) -> [Target] {
        var rootTargets = [Target]()

        // Create a map of targets
        for target in targets {
            targetMap[target.id] = target
        }

        // Populate children arrays and build the tree
        for target in targets {
            if let parentID = target.parent, parentID != -1 {
                if let parent = targetMap[parentID] {
                    if parent.children == nil {
                        parent.children = []
                    }
                    if !parent.children!.contains(target.id) {
                        parent.children!.append(target.id)
                    }
                    targetMap[parentID] = parent
                }
            } else {
                rootTargets.append(target)
            }
        }
//        print("buildTree    ", targetMap)
        return rootTargets
    }

//    func addTarget(value: String, toParent parentId: Int) -> Int {
    func addTarget(key:String, value: String, toParent parentId: Int, metadata: [String: Any]? = nil) -> Int {
//        print("addTarget: metadata=", metadata)
        if var parent = targetMap[parentId] {
            if let existingChild = parent.hasValues(withValue: value) {
//                print("Child with value '\(value)' already exists: \(existingChild)")
                return existingChild.id
            }
            if let newChild = parent.add(key: key, value: value, metadata: metadata) {
//                setHighlight(newChild)
                let vulnerabilityDatabase = VulnerabilityDatabase()
                let chatViewModel = ChatViewModel.shared
//                @EnvironmentObject var chatViewModel: ChatViewModel
                let key = "CriticalScan"
                let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let result = vulnerabilityDatabase.searchValue(for: trimmedValue) {
                    print("Found: \(result)")
                    setHighlight(newChild)
                    if let machineName = result["machine_name"] as? String {
                        print("Similar machine is " + machineName)
                        for (key, value) in result {
                            if key != "machine_name" {
                                if let valueString = value as? String {
//                                    print("Key: \(key), Value: \(valueString)")
                                    chatViewModel.sendMessage("\(valueString) is interesting. Similar machine is " + machineName, isUser: false)
                                }
                            }
                        }
                    } else {
                        print("Error: machine_name not found or not a String in result")
                    }
                } else {
//                    print("Not found: targetValues=", trimmedValue)
                }
                
                targetMap[parentId] = parent
                targetMap[newChild.id] = newChild
                self.targets = buildTree(targets: Array(targetMap.values))
                return newChild.id
            }
        }
        return 0
    }

    func removeTarget(target: Target) {
        // Recursively remove all children
        if let children = target.children {
            for childId in children {
                if let childTarget = targetMap[childId] {
                    removeTarget(target: childTarget)
                }
            }
        }
        
        // Remove the target itself
        targetMap.removeValue(forKey: target.id)
        if let index = targets.firstIndex(where: { $0.id == target.id }) {
            targets.remove(at: index)
        }
        
        // Update parent if needed
        if let parentId = target.parent, parentId != -1, var parent = targetMap[parentId] {
            parent.children?.removeAll(where: { $0 == target.id })
            targetMap[parentId] = parent
        }

        // Rebuild the targets array to update the UI
        self.targets = buildTree(targets: Array(targetMap.values))
    }

    func updateTarget(_ target: Target, with newKey: String, _ newValue: String, _ newMetadata: [String: Any]) {
        if let index = targets.firstIndex(where: { $0.id == target.id }) {
            targets[index].key = newKey
            targets[index].value = newValue
            targets[index].metadata = newMetadata
            targetMap[target.id]?.key = newKey
            targetMap[target.id]?.value = newValue
            targetMap[target.id]?.metadata = newMetadata
            self.targets = buildTree(targets: Array(targetMap.values))
            saveJSON()
        }
    }

    func setHighlight(_ target: Target) {
//        target.shouldHighlight = true
        targetMap[target.id]?.shouldHighlight = true
    }

    // New function to process input
    func processInput(_ input: String, key: String? = nil, metadata: [String: Any]? = nil) {
        let lines = input.components(separatedBy: "\n").filter { !$0.isEmpty }
        for line in lines {
            let components = line.components(separatedBy: "\t")
            guard components.count >= 2 else { continue }

            let ip = components[0]
            let port = components[1]
            let details = components.dropFirst(2)

            var parentId: Int
            // Check if IP node exists
            if let ipNode = targetMap.values.first(where: { $0.value == ip }) {
                parentId = ipNode.id
            } else {
                // Add IP node with "ipaddress" metadata if available
                var ipMetadata: [String: Any]? = nil
                if let metadata = metadata, let ipAddress = metadata["ipaddress"] as? String {
                    ipMetadata = ["ipaddress": ipAddress]
                }
//                print("ipaddress contains ipMetadata=", ipMetadata)
                parentId = addTarget(key: "host", value: ip, toParent: 0, metadata: ipMetadata)
            }

            // Check if Port node exists
            if let portNode = targetMap.values.first(where: { $0.value == port && $0.parent == parentId }) {
                parentId = portNode.id
            } else {
                // Add Port node
                parentId = addTarget(key:"port", value: port, toParent: parentId)
            }

            // Add details nodes
            for detail in details {
                if !detail.isEmpty {
                    parentId = addTarget(key: key ?? "detail", value: detail, toParent: parentId)
                }
            }
        }

        let targets = buildTree(targets: Array(targetMap.values))
        // Do something with the targets, e.g., assign to a property or process further
    //    print(targets)  // Just for debugging
    }

    
    func saveJSON() {
        do {
            print("saveJSON")
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
//            let data = try encoder.encode(targetMap)
            let data = try encoder.encode(Array(targetMap.values))
//            let data = try encoder.encode(targets)
            let url = getDocumentsDirectory().appendingPathComponent("targets.json")
            try data.write(to: url)
            print("Data saved successfully at \(url.path)")
            
            // For debugging
            let projectDirectory = "/Users/yu/work/EchidnaApp/release/EchidnaTermApp/EchidnaTermApp/TargetTree"
            let filePath = "\(projectDirectory)/targets.json"
            let urlDebug = URL(fileURLWithPath: filePath)
            try data.write(to: urlDebug)
            print("Data saved successfully at \(urlDebug.path)")
            
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsDirectory.appendingPathComponent("targets.json")
            try data.write(to: fileURL)
            
        } catch {
            print("Error saving JSON: \(error)")
        }
    }

    func searchTarget(with value: String) {
        for target in targets {
            if let result = target.containsValue(value: value) {
                searchResult = result
                break
            }
        }
    }
    
    private func expandParent(_ target: Target) {
        target.shouldHighlight = true
        if let parentId = target.parent, let parent = targetMap[parentId] {
            expandParent(parent)
        }
    }
    
    private func highlightTarget(_ target: Target) {
        target.shouldHighlight = true
        if let parentId = target.parent, let parent = targetMap[parentId] {
            expandParent(parent)
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

class Target: Identifiable, Codable, CustomStringConvertible {
    let id: Int
    var key: String
    var value: String
    var parent: Int?
    var children: [Int]?
    var metadata: [String: Any]?
    @Published var shouldHighlight: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case key
        case value
        case parent
        case children
        case metadata
        case shouldHighlight
    }

    init(id: Int, key: String, value: String, parent: Int? = nil, children: [Int]? = nil, metadata: [String: Any]? = nil, shouldHighlight: Bool = false) {
        self.id = id
        self.key = key
        self.value = value
        self.parent = parent
        self.children = children
        self.metadata = metadata
        self.shouldHighlight = shouldHighlight
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        key = try container.decode(String.self, forKey: .key)
        value = try container.decode(String.self, forKey: .value)
        parent = try container.decodeIfPresent(Int.self, forKey: .parent)
        children = try container.decodeIfPresent([Int].self, forKey: .children)
        shouldHighlight = try container.decodeIfPresent(Bool.self, forKey: .shouldHighlight) ?? false
        if let metadataData = try container.decodeIfPresent(Data.self, forKey: .metadata) {
            metadata = try JSONSerialization.jsonObject(with: metadataData, options: []) as? [String: Any]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(key, forKey: .key)
        try container.encode(value, forKey: .value)
        try container.encode(parent, forKey: .parent)
        try container.encode(children, forKey: .children)
        try container.encode(shouldHighlight, forKey: .shouldHighlight)
        if let metadata = metadata {
            let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [])
            try container.encode(metadataData, forKey: .metadata)
        }
    }


    // Dynamically resolve children targets
    var childrenTargets: [Target]? {
        guard let children = children else { return nil }
        return children.compactMap { id in
            targetMap[id]
        }
    }

    func add(key:String, value: String, metadata: [String: Any]? = nil) -> Target? {
        // Check if a child with the same value already exists
        if let children = self.children {
            for childId in children {
//                let tmpchild = targetMap[childId]
//                print("tmpchild = ", tmpchild, " value=", value)
                if let child = targetMap[childId], child.value == value {
                    print("childExists")
                    return nil
                }
            }
        }

        // Create a new child
        let newId = (targetMap.keys.max() ?? 0) + 1
        let child = Target(id: newId, key: key, value: value, parent: self.id, children: nil, metadata: metadata)

        // Update the parent's children array
        if self.children == nil {
            self.children = []
        }
        self.children?.append(child.id)

        // Update the target map
        targetMap[child.id] = child
        targetMap[self.id] = self

        return child
    }
    
    // Helper method to check if a child with the same value already exists
    func hasValues(withValue value: String) -> Target? {
        if let children = self.children {
//            print("hasValues    children = ", children)

            for childId in children {
                if let tmpchild = targetMap[childId] {
//                    print("hasValues    tmpchild = \(tmpchild), target value = \(tmpchild.value), comparison value = \(value)")
                    if tmpchild.value == value {
//                        print("Duplicate child=", tmpchild)
                        return tmpchild
                    }
                }
            }
        }
        return nil
    }
    
    func containsValue(value: String) -> Target? {
        let lowercasedValue = value.lowercased()
        if self.value.lowercased().contains(lowercasedValue) {
            return self
        }
        if let childrenTargets = self.childrenTargets {
            for child in childrenTargets {
                if let result = child.containsValue(value: lowercasedValue) {
                    return result
                }
            }
        }
        return nil
    }
    
    var description: String {
        return "Target(id: \(id), key: \(key), value: \(value), parent: \(parent ?? -1), children: \(children ?? []), shouldHighlight: \(shouldHighlight), metadata: \(String(describing: metadata))"
    }
    
}
