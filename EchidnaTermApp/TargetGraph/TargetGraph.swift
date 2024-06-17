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
    @Published var position: CGPoint = .zero
    @Published var isHighlighted: Bool = false
    
    init(target: Target) {
        self.id = target.id
        self.value = target.value
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
        print("Graph: filteredTargets=", filteredTargets)
        nodes = filteredTargets.map { Node(target: $0) }
        
        for node in nodes {
            graph.addVertex(String(node.id))
        }
        
        edges = filteredTargets.flatMap { target in
            target.children?.map { childId in
                Edge(from: target.id, to: childId)
            } ?? []
        }
        for edge in edges {
            graph.addEdge(from: String(edge.from), to: String(edge.to), directed: true)
        }
        
        updateNodePositions(geometry: geometry)
        updateEdgePositions()
    }
    
    private func updateNodePositions(geometry: CGSize) {
        let center = CGPoint(x: geometry.width / 2, y: geometry.height / 2)
        let radius: CGFloat = min(geometry.width, geometry.height) / 3
        let angleIncrement = CGFloat(2 * Double.pi) / CGFloat(nodes.count)
        
        for (index, node) in nodes.enumerated() {
            nodes[index].position = CGPoint(
                x: center.x + radius * cos(angleIncrement * CGFloat(index)),
                y: center.y + radius * sin(angleIncrement * CGFloat(index))
            )
        }
    }
    
    private func updateEdgePositions() {
        for edge in edges {
            if let fromNode = nodes.first(where: { $0.id == edge.from }),
               let toNode = nodes.first(where: { $0.id == edge.to }) {
                print("Graph: toNode=", toNode.value)
                edge.fromPosition = fromNode.position
                edge.toPosition = toNode.position
            }
        }
    }
    
    private func highlightNodes() {
        let matchingHosts = findHostsMatching(searchText)
        print("highlightNodes: matchingHosts=", matchingHosts)
        for node in nodes {
            node.isHighlighted = matchingHosts.contains(node.value) && !searchText.isEmpty
            print("Graph: : node.isHighlighted=", node.isHighlighted)
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
            Image(systemName: "server.rack")
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(node.isHighlighted ? .yellow : .black)
            Text(node.value)
                .padding(8)
                .background(Circle().fill(node.isHighlighted ? Color.yellow.opacity(0.5) : Color.blue.opacity(0.5)))
        }
        .position(x: node.position.x, y: node.position.y)
        .onTapGesture {
            showingDetail = true
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
                            CandidateCommandView()
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
