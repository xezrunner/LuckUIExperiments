// LuckUIExperiments::LuckTabButtonExpandedLabel.swift - 11/04/2025

import SwiftUI

struct LuckTabViewStripCompactButton: View, Identifiable {
    let id = UUID()
    
    var animNS: Namespace.ID
    
    var icon: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .contentTransition(.symbolEffect(.automatic))
                    .frame(width: 24, height: 24)
                    .padding(12)
            }
        }
        .foregroundStyle(.secondary)
        .drawingGroup() // This is required, as the symbol transition leaves a trail otherwise.
    }
}

struct LuckTabViewStripButton: View, Identifiable {
    let id = UUID()
    
    var animNS: Namespace.ID
    
    var isSelected: Bool = false
    
    var icon: String
    var title: String
    
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .scaleEffect(1.25)
                    .matchedGeometryEffect(id: "luckTabViewStripTabButtonLabelIcon\(!isSelected ? id.uuidString : icon)", in: animNS)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.footnote)
                    .fixedSize(horizontal: true, vertical: false)
            }
                        .matchedGeometryEffect(id: "luckTabViewStripTabButtonLabel\(!isSelected ? id.uuidString : icon)", in: animNS, properties: .position)
            
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(isSelected ? .accent : .secondary)
        .background {
            if isSelected {
                Capsule().fill(.background)
                    .matchedGeometryEffect(id: "luckTabViewStripTabButton\(isSelected ? "" : id.uuidString)", in: animNS)
            }
        }
    }
}
