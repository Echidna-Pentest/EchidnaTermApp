//
//  TargetGraph.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/05/27.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.

import SwiftUI
import Combine
import SwiftGraph

class Node: Identifiable, ObservableObject {
    let id: Int
    let value: String
    let ipAddress: String?
    let isSubnet: Bool
    @Published var position: CGPoint = .zero
    @Published var isHighlighted: Bool = false
    
    init(target: Target, isSubnet: Bool = false) {
        self.id = target.id
        self.value = target.value
        self.ipAddress = target.metadata?["ipaddress"] as? String
        self.isSubnet = isSubnet
    }
}

class Edge: Identifiable, ObservableObject {
    let id = UUID()
    let from: Int
    let to: Int
    @Published var fromPosition: CGPoint = .zero
    @Published var toPosition: CGPoint = .zero
    
    init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }
}

struct TargetGraphView: View {
    @State private var nodes: [Node] = []
    @State private var edges: [Edge] = []
    @State private var graph: UnweightedGraph<String> = UnweightedGraph<String>()
    @State private var searchText: String = ""
    
    var body: some View {
        VStack {
            TextField("Search...", text: $searchText)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding([.leading, .trailing])
                .onChange(of: searchText) { _ in
                    highlightNodes()
                }
            
            GeometryReader { geometry in
                ZStack {
                    ForEach(edges) { edge in
                        EdgeView(edge: edge, nodes: nodes)
                    }
                    ForEach(nodes) { node in
                        NodeView(node: node, geometry: geometry.size, searchText: searchText)
                    }
                }
                .onAppear {
                    processTargets(geometry: geometry.size)
                }
            }
        }
    }
       
    private func processTargets(geometry: CGSize) {
        let filteredTargets = targetMap.values.filter { $0.key == "Network" || $0.key == "host" }
        nodes = filteredTargets.map { Node(target: $0) }

        /*
        for node in nodes {
            graph.addVertex(String(node.id))
        }
        */
        
        edges = []
        processIPAddresses()
        
        // Ensure no direct edges from Target Network to host nodes
        for target in filteredTargets {
            if target.key == "host", let parent = target.parent {
                if let parentTarget = targetMap[parent], parentTarget.key != "subnet" {
                    // Skip creating an edge from Target Network to host
                    continue
                }
            }
        }
        
        updateNodePositions(geometry: geometry)
        updateEdgePositions()
    }

    private func processIPAddresses() {
        var ipSubnetNodes: [String: Node] = [:]
        
        if let targetNetworkNode = nodes.first(where: { $0.value == "Target Network" }) {
            for node in nodes {
                if let ipAddress = node.ipAddress ?? extractIPAddress(from: node.value) {
                    if isPrivateIP(ipAddress) {
                        let subnet = getSubnet(from: ipAddress)
                        if ipSubnetNodes[subnet] == nil {
                            let subnetNode = Node(target: Target(id: nodes.count + ipSubnetNodes.count, key: "subnet", value: subnet, parent: targetNetworkNode.id, children: nil), isSubnet: true)
                            ipSubnetNodes[subnet] = subnetNode
                            nodes.append(subnetNode)
//                            graph.addVertex(String(subnetNode.id))
                            
                            // Link Target Network to subnet
                            edges.append(Edge(from: targetNetworkNode.id, to: subnetNode.id))
                            graph.addEdge(from: String(targetNetworkNode.id), to: String(subnetNode.id), directed: true)
                        }
                        
                        if let subnetNode = ipSubnetNodes[subnet] {
                            edges.append(Edge(from: subnetNode.id, to: node.id))
                            graph.addEdge(from: String(subnetNode.id), to: String(node.id), directed: true)
                        }
                    } else {
                        // For public IPs, create a direct edge to the target network
                        edges.append(Edge(from: targetNetworkNode.id, to: node.id))
                        graph.addEdge(from: String(targetNetworkNode.id), to: String(node.id), directed: true)
                    }
                }
            }
        }
    }

    
    private func extractIPAddress(from value: String) -> String? {
        let pattern = #"(\d{1,3}\.){3}\d{1,3}"#
        if let range = value.range(of: pattern, options: .regularExpression) {
            return String(value[range])
        }
        return nil
    }
    
    private func getSubnet(from ipAddress: String) -> String {
        let components = ipAddress.split(separator: ".")
        guard components.count == 4 else { return ipAddress }
        return "\(components[0]).\(components[1]).\(components[2]).0/24"
    }
    
    private func isPrivateIP(_ ipAddress: String) -> Bool {
        let privateIPRanges = [
            "10.",
            "172.16.", "172.17.", "172.18.", "172.19.", "172.20.",
            "172.21.", "172.22.", "172.23.", "172.24.", "172.25.",
            "172.26.", "172.27.", "172.28.", "172.29.", "172.30.",
            "172.31.",
            "192.168."
        ]
        return privateIPRanges.contains { ipAddress.starts(with: $0) }
    }
    
    private func updateNodePositions(geometry: CGSize) {
        let rootNode = nodes.first { $0.value == "Target Network" }
        var levels: [[Node]] = []
        
        func assignLevels(node: Node, level: Int) {
            if levels.count <= level {
                levels.append([])
            }
            levels[level].append(node)
            
            for edge in edges {
                if edge.from == node.id {
                    if let childNode = nodes.first(where: { $0.id == edge.to }) {
                        assignLevels(node: childNode, level: level + 1)
                    }
                }
            }
        }
        
        if let rootNode = rootNode {
            assignLevels(node: rootNode, level: 0)
        }

        let levelHeight: CGFloat = geometry.height / CGFloat(max(1, levels.count))
        
        for (levelIndex, levelNodes) in levels.enumerated() {
            let nodeWidth: CGFloat = geometry.width / CGFloat(max(1, levelNodes.count))
            for (nodeIndex, node) in levelNodes.enumerated() {
                nodes[nodes.firstIndex(where: { $0.id == node.id })!].position = CGPoint(
                    x: nodeWidth * CGFloat(nodeIndex) + nodeWidth / 2,
                    y: levelHeight * CGFloat(levelIndex) + levelHeight / 2
                )
            }
        }
        
        updateEdgePositions()
    }
    
    private func updateEdgePositions() {
        for edge in edges {
            if let fromNode = nodes.first(where: { $0.id == edge.from }),
               let toNode = nodes.first(where: { $0.id == edge.to }) {
                edge.fromPosition = fromNode.position
                edge.toPosition = toNode.position
            }
        }
    }
    
    private func highlightNodes() {
        let matchingHosts = findHostsMatching(searchText)
        for node in nodes {
            node.isHighlighted = matchingHosts.contains(node.value) && !searchText.isEmpty
        }
    }

    private func findHostsMatching(_ searchText: String) -> Set<String> {
        var matchingHosts: Set<String> = []
        for node in nodes {
            if let target = targetMap[node.id] {
                if target.value.lowercased().contains(searchText.lowercased()) ||
                   (findParentHost(for: target, matching: searchText.lowercased()) != nil) {
                    if target.key == "host" {
                        matchingHosts.insert(target.value)
                    } else if let host = findHostAncestor(of: target) {
                        matchingHosts.insert(host.value)
                    }
               }
            }
        }
        return matchingHosts
    }

    private func findParentHost(for target: Target, matching value: String) -> Target? {
        if target.value.lowercased().contains(value) {
            return findHostAncestor(of: target)
        }
        if let childrenTargets = target.childrenTargets {
            for child in childrenTargets {
                if let result = findParentHost(for: child, matching: value) {
                    return result
                }
            }
        }
        return nil
    }

    private func findHostAncestor(of target: Target) -> Target? {
        var currentTarget: Target? = target
        while let parent = currentTarget?.parent, let parentTarget = targetMap[parent] {
            if parentTarget.key == "host" {
                return parentTarget
            }
            currentTarget = parentTarget
        }
        return nil
    }
}

struct NodeView: View {
    @ObservedObject var node: Node
    let geometry: CGSize
    @State private var showingDetail = false
    @ObservedObject var connections = Connections.shared
    var searchText: String
    
    init(node: Node, geometry: CGSize, searchText: String) {
        self.node = node
        self.geometry = geometry
        self.searchText = searchText
    }

    var body: some View {
        VStack {
            icon(for: node)
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(node.isHighlighted ? .yellow : .black)
            Text(node.value)
                .padding(8)
                .background(Circle().fill(node.isHighlighted ? Color.yellow.opacity(0.5) : Color.blue.opacity(0.5)))
        }
        .position(x: node.position.x, y: node.position.y)
        .onTapGesture {
            if !node.isSubnet && isHost(node: node) {
                showingDetail = true
            }
        }
        .fullScreenCover(isPresented: $showingDetail) {
            if let target = targetMap[node.id] {
                VStack {
                    HStack {
                        FilteredTargetTreeView(rootTarget: target, initialSearchText: searchText)
                            .frame(maxWidth: .infinity)
                        VStack {
                            if let terminalView = connections.getTerminals().first {
                                TerminalViewRepresentable(terminalView: terminalView)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: geometry.height * 0.6)
                            }
                            CandidateCommandView(isSinglePage: false)
                                .frame(maxWidth: .infinity)
                                .frame(height: geometry.height * 0.4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        HStack {
                            Spacer()
                            VStack {
                                Button(action: {
                                    showingDetail = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .foregroundColor(.black)
                                        .padding()
                                }
                                Spacer()
                            }
                        }
                    )
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
    }

    private func icon(for node: Node) -> Image {
        if node.isSubnet || node.value == "Target Network" {
            return Image(systemName: "network")
        } else if isHost(node: node) {
            return Image(systemName: "desktopcomputer")
        } else {
            return Image(systemName: "questionmark.circle")
        }
    }

    private func isHost(node: Node) -> Bool {
        // Check if the node is a host by checking for an IP address or a pattern matching an IP address
        if let ipAddress = node.ipAddress, isValidIPAddress(ipAddress) {
            return true
        } else if isValidIPAddress(node.value) {
            return true
        }
        return false
    }

    private func isValidIPAddress(_ value: String) -> Bool {
        let pattern = #"(\d{1,3}\.){3}\d{1,3}"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private func isPrivateIP(_ ipAddress: String) -> Bool {
        let privateIPRanges = [
            "10.",
            "172.16.", "172.17.", "172.18.", "172.19.", "172.20.",
            "172.21.", "172.22.", "172.23.", "172.24.", "172.25.",
            "172.26.", "172.27.", "172.28.", "172.29.", "172.30.",
            "172.31.",
            "192.168."
        ]
        return privateIPRanges.contains { ipAddress.starts(with: $0) }
    }

    private func isPublicIP(_ ipAddress: String) -> Bool {
        return !isPrivateIP(ipAddress)
    }
}


struct EdgeView: View {
    @ObservedObject var edge: Edge
    let nodes: [Node]

    var body: some View {
        Path { path in
            path.move(to: edge.fromPosition)
            path.addLine(to: edge.toPosition)
        }
        .stroke(Color.blue, lineWidth: 2)
    }
}

struct TerminalViewRepresentable: UIViewRepresentable {
    let terminalView: SshTerminalView
    
    func makeUIView(context: Context) -> UIView {
        return terminalView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        terminalView.disableFirstResponderDuringViewRehosting = true
        terminalView.disableFirstResponderDuringViewRehosting = false
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        TerminalViewController.visibleTerminal = terminalView

        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: uiView.safeAreaLayoutGuide.topAnchor),
            terminalView.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: uiView.trailingAnchor),
            terminalView.heightAnchor.constraint(equalTo: uiView.heightAnchor, multiplier: 0.6)
        ])
    }
}
