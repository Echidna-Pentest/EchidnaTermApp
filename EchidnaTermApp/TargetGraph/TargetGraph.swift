//
//  TargetGraph.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/05/27.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.

import SwiftUI
import Combine
import SwiftGraph

struct Node: Identifiable {
    let id: Int
    let value: String
    var position: CGPoint = .zero
    
    init(target: Target) {
        self.id = target.id
        self.value = target.value
    }
}

struct Edge: Identifiable {
    let id = UUID()
    let from: Int
    let to: Int
}

struct TargetGraphView: View {
    @State private var nodes: [Node] = []
    @State private var edges: [Edge] = []
    @State private var graph: UnweightedGraph<String> = UnweightedGraph<String>()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(edges) { edge in
                    EdgeView(edge: edge, nodes: nodes)
                }
                ForEach(nodes) { node in
                    NodeView(node: node, geometry: geometry.size)
                }
            }
            .onAppear {
                processTargets(geometry: geometry.size)
            }
        }
    }
    
    private func processTargets(geometry: CGSize) {
        let filteredTargets = targetMap.values.filter { $0.key == "Network" || $0.key == "host" }
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
}

struct NodeView: View {
    @State private var node: Node
    let geometry: CGSize
    @State private var showingDetail = false
    @ObservedObject var connections = Connections.shared
    
    init(node: Node, geometry: CGSize) {
        self._node = State(initialValue: node)
        self.geometry = geometry
    }

    var body: some View {
        VStack {
            Image(systemName: "server.rack")
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(.black)
            Text(node.value)
                .padding(8)
                .background(Circle().fill(Color.blue.opacity(0.5)))
        }
        .position(x: node.position.x, y: node.position.y)
        .onTapGesture {
            showingDetail = true
        }
        .fullScreenCover(isPresented: $showingDetail) {
            if let target = targetMap[node.id] {
                VStack {
                    HStack {
                        FilteredTargetTreeView(rootTarget: target)
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
    let edge: Edge
    let nodes: [Node]

    var body: some View {
        if let fromNode = nodes.first(where: { $0.id == edge.from }),
           let toNode = nodes.first(where: { $0.id == edge.to }) {
            Path { path in
                path.move(to: fromNode.position)
                path.addLine(to: toNode.position)
            }
            .stroke(Color.blue, lineWidth: 2)
        }
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