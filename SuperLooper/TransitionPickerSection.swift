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
            Picker("Style", selection: $transition) {
                ForEach(TransitionType.availableCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.iconName).tag(type)
                }
            }
            
            Text(transition.normalized.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speed")
                    Spacer()
                    Text(String(format: "%.1fs", transitionDuration))
                        .foregroundColor(.secondary)
                }
                Slider(value: $transitionDuration, in: 0.2...2.0, step: 0.1)
            }
        } header: {
            Label("Transition", systemImage: "arrow.right.arrow.left")
        }
    }
}
