//
//  CommandDetailsView.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/07/14.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import Foundation
import SwiftUI

struct CommandDetailsView: View {
    let command: Command

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Command Details")
                .font(.title)
                .fontWeight(.semibold)
                .padding(.bottom, 8)

            detailRow(title: "Template:", value: command.template)
            detailRow(title: "Patterns:", value: command.patterns.joined(separator: ", "))
            detailRow(title: "Condition:", value: command.condition.joined(separator: ", "))
            detailRow(title: "Group:", value: command.group ?? "None")
            detailRow(title: "Description:", value: command.description.replacingOccurrences(of: "\\n", with: "\n"), isDescription: true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding()
    }

    @ViewBuilder
    private func detailRow(title: String, value: String, isDescription: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .fontWeight(.bold)
                    .foregroundColor(Color(.systemBlue))
                Spacer()
            }
            Text(value)
                .multilineTextAlignment(isDescription ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(.vertical, 4)
    }
}
