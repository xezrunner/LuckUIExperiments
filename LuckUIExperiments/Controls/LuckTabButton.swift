// LuckUIExperiments::LuckTabButtonExpandedLabel.swift - 11/04/2025

import SwiftUI

struct LuckTabButtonExpandedLabel: LabelStyle {
    let id: UUID
    let animNS: Namespace.ID
    
    var isCompact = true
    var isSelected = true
    
    @State private var titleTrigger = false
    
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            configuration.icon
                .frame(width: 24, height: 24)
                .scaleEffect(isCompact ? 1.15 : 1.3)
                .matchedGeometryEffect(id: !isSelected ? "TabButtonIcon::\(id.uuidString)" : "ActiveTabButtonIcon",
                                       in: animNS, properties: .position)
            
                configuration.title
                    .font(.footnote)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: isCompact ? 0 : nil)
                    .padding(.top, !isCompact ? 4 : 0)
                    .opacity(isCompact ? 0 : 1)
                    .matchedGeometryEffect(id: !isSelected ? "TabButtonLabel::\(id.uuidString)" : "ActiveTabButtonLabel",
                                           in: animNS, properties: .position)
        }
        .padding(.horizontal, isCompact ? 0 : 4)
        .foregroundStyle(.tint)
        .tint(isCompact ? .secondary : (isSelected ? nil : .secondary))
    }
}

struct LuckTabButton<Label: View>: View {
    let id = UUID()
    let animNS: Namespace.ID
    
    var isCompact = false
    var isSelected = false
    
    var action: () -> Void
    @ViewBuilder var label: Label
    
    var body: some View {
        ZStack {
            Button(action: action) {
                label
                    .labelStyle(LuckTabButtonExpandedLabel(id: id, animNS: animNS, isCompact: isCompact, isSelected: isSelected))
            }
        }
        .frame(width: isCompact ? 50 : nil, height: isCompact ? 50 : nil)
        .padding(!isCompact ? 8 : 0)
        .background {
            Capsule(style: .continuous)
                .fill(BackgroundStyle.background)
                .opacity(isSelected ? 1 : 0)
                .matchedGeometryEffect(id: !isSelected ? "TabButton::\(id.uuidString)" : "ActiveTabButton", in: animNS)
                .frame(width: isCompact ? nil : 90)
                .compositingGroup()
                .shadow(color: .black.opacity(!isSelected ? 0 : 0.1), radius: isCompact ? 0 : 4)
        }
    }
}
