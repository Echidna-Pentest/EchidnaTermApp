import SwiftUI

var targetMap = [Int: Target]()

class TargetTreeViewModel: ObservableObject {
    static let shared = TargetTreeViewModel()
    @Published var targets: [Target] = []

    init() {
        loadJSON()
    }

    func loadJSON() {
        print("loadJSON")
        if let url = Bundle.main.url(forResource: "targets", withExtension: "json") {
            //let url = getDocumentsDirectory().appendingPathComponent("targets.json")
        /*
        let projectDirectory = "/Users/yu/work/EchidnaApp/release/EchidnaTermApp/EchidnaTermApp/TargetTree"
        let filePath = "\(projectDirectory)/targets.json"
        let url = URL(fileURLWithPath: filePath)
         */
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
                if var parent = targetMap[parentID] {
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
        print("buildTree    ", targetMap.mapValues { "\($0)" })
        return rootTargets
    }

//    func addTarget(value: String, toParent parentId: Int) -> Int {
    func addTarget(key:String, value: String, toParent parentId: Int) -> Int {
        print("addTarget: parentId", parentId)
        if var parent = targetMap[parentId] {
//            print("addTarget parent = ", parent)
            if let existingChild = parent.hasValues(withValue: value) {
                print("Child with value '\(value)' already exists: \(existingChild)")
                return existingChild.id
//                return 0
            }
            if let newChild = parent.add(key: key, value: value) {
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
                        chatViewModel.sendMessage("Similar machine is " + machineName, isUser: false)
                    } else {
                        print("Similar machine is not String!")
                        print("Error: machine_name not found or not a String in result")
                    }
                } else {
                    print("Not found: targetValues=", trimmedValue)
                }
                
                targetMap[parentId] = parent
                targetMap[newChild.id] = newChild
                self.targets = buildTree(targets: Array(targetMap.values))
                return newChild.id
            }
        }
        return 0
    }

    func removeTarget(byId id: Int) {
        if let index = targets.firstIndex(where: { $0.id == id }) {
            targets.remove(at: index)
            targetMap.removeValue(forKey: id)
            self.targets = buildTree(targets: Array(targetMap.values))
        }
    }

    func updateTarget(_ target: Target) {
        if let index = targets.firstIndex(where: { $0.id == target.id }) {
            targets[index] = target
            targetMap[target.id] = target
            self.targets = buildTree(targets: Array(targetMap.values))
        }
    }

    func setHighlight(_ target: Target) {
//        target.shouldHighlight = true
        targetMap[target.id]?.shouldHighlight = true
    }

    // New function to process input
    func processInput(_ input: String) {
        let lines = input.components(separatedBy: "\n").filter { !$0.isEmpty }
        for line in lines {
            print("processInput     ", line)
            let components = line.components(separatedBy: "\t")
            guard components.count >= 3 else { continue }

            let ip = components[0]
            let port = components[1]
            let details = components.dropFirst(2)

            var parentId: Int? = nil
            var tmpParentId = 0
            // Check if IP node exists
            if let ipNode = targetMap.values.first(where: { $0.value == ip }) {
                tmpParentId = ipNode.id
            } else {
                // Add IP node
//                tmpParentId = addTarget(value: ip, toParent: 2)
                print("addHost ip=", ip)
                tmpParentId = addTarget(key: "host", value: ip, toParent: 0)
                print("tmpParentId=", tmpParentId)
            }

            // Check if Port node exists
            if let portNode = targetMap.values.first(where: { $0.value == port && $0.parent == parentId }) {
                print("test Not Add PortNode")
                tmpParentId = portNode.id
            } else {
                // Add Port node
//                tmpParentId = addTarget(value: port, toParent: tmpParentId)
                print("test Add PortNode")
                tmpParentId = addTarget(key:"port", value: port, toParent: tmpParentId)
            }

            // Check if SMBDrive node exists
            // Add details nodes
            for detail in details {
                if !detail.isEmpty {
//                    tmpParentId = addTarget(value: detail, toParent: tmpParentId)
                    tmpParentId = addTarget(key:"detail", value: detail, toParent: tmpParentId)
                }
            }
        }

        self.targets = buildTree(targets: Array(targetMap.values))
    }
    
    func saveJSON() {
        do {
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
        } catch {
            print("Error saving JSON: \(error)")
        }
    }

    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

class Target: Identifiable, Codable, CustomStringConvertible {
    let id: Int
    let key: String
    let value: String
    var parent: Int?
    var children: [Int]?
    @Published var shouldHighlight: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, key, value, parent, children
    }

    init(id: Int, key: String, value: String, parent: Int?, children: [Int]?) {
        self.id = id
        self.key = key
        self.value = value
        self.parent = parent
        self.children = children
    }

    // Dynamically resolve children targets
    var childrenTargets: [Target]? {
        guard let children = children else { return nil }
        return children.compactMap { id in
            targetMap[id]
        }
    }

    func add(key:String, value: String) -> Target? {
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
        let child = Target(id: newId, key: key, value: value, parent: self.id, children: nil)

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
                    print("hasValues    tmpchild = \(tmpchild), target value = \(tmpchild.value), comparison value = \(value)")
                    if tmpchild.value == value {
                        print("Duplicate child=", tmpchild)
                        return tmpchild
                    }
                }
            }
        }
        return nil
    }
    
    var description: String {
        return "Target(id: \(id), key: \(key), value: \(value), parent: \(parent ?? -1), children: \(children ?? []), shouldHighlight: \(shouldHighlight))"
    }
}
