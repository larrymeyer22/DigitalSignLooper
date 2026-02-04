//
//  TransitionPickerSection.swift
//  Super Looper
//
//  Reusable Form section for selecting a per-item transition type and duration.
//  Drop this into any content editor's Form.
//

import SwiftUI

struct TransitionPickerSection: View {
    @Binding var transition: TransitionType
    @Binding var transitionDuration: Double
    
    var body: some View {
        Section {
            Picker("Transition Type", selection: $transition) {
                ForEach(TransitionType.availableCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            
            Text(transition.normalized.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(String(format: "%.1fs", transitionDuration))
                        .foregroundColor(.secondary)
                }
                Slider(value: $transitionDuration, in: 0.2...2.0, step: 0.1)
            }
        } header: {
            Label("Transition", systemImage: "arrow.right.arrow.left")
        } footer: {
            Text("Transition effect when advancing to the next item")
        }
    }
}
