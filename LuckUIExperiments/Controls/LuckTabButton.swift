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
                    .matchedGeometryEffect(id: "luckTabViewStripTabButtonLabelIcon", in: animNS)
                    .frame(width: 24, height: 24)
                    .padding(12)
            }
            .matchedGeometryEffect(id: "luckTabViewStripTabButtonLabel", in: animNS, properties: .position)
        }
        .foregroundStyle(.secondary)
        .background(
            Capsule().fill(.background)
                .matchedGeometryEffect(id: "luckTabViewStripTabButton", in: animNS)
        )
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
                    .imageScale(.large)
                    .matchedGeometryEffect(id: "luckTabViewStripTabButtonLabelIcon\(!isSelected ? id.uuidString : "")", in: animNS)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.footnote)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(isSelected ? .accent : .secondary)
            
            .matchedGeometryEffect(id: "luckTabViewStripTabButtonLabel\(!isSelected ? id.uuidString : "")", in: animNS, properties: .position)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .background {
            if isSelected {
                Capsule().fill(.background)
                    .matchedGeometryEffect(id: "luckTabViewStripTabButton", in: animNS)
            }
        }
    }
}

#if false
struct LuckTabButtonExpandedLabel: LabelStyle, Identifiable {
    let id: String
    let animNamespace: Namespace.ID
    
    @Environment(\.luckTabViewAnimation) var tabViewAnimation
    
    var isCompact  = true
    var isSelected = true
    
    @State private var titleTrigger = false
    
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            configuration.icon
                .frame(width: 24, height: 24)
                .scaleEffect(isCompact ? 1.15 : 1.3)
//                .matchedGeometryEffect(id: !isSelected ? "TabButtonIcon::\(id.uuidString)" : "ActiveTabButtonIcon",
//                                       in: animNamespace, properties: .position)
            
            configuration.title
                .font(.footnote)
            
                .fixedSize(horizontal: true, vertical: false) // Prevent text truncation
                .frame(height: isCompact ? 0 : nil)
                .padding(.top, !isCompact ? 4 : 0)
            
                .opacity(isCompact ? 0 : 1)
            
//                .matchedGeometryEffect(id: !isSelected ? "TabButtonLabel::\(id.uuidString)" : "ActiveTabButtonLabel",
//                                       in: animNamespace, properties: .position)
        }
        .padding(.horizontal, isCompact ? 0 : 4)
        .foregroundStyle(.tint)
        .tint(isCompact ? .secondary : (isSelected ? nil : .secondary))
    }
}

struct LuckTabButton<Label: View>: View, Identifiable {
    let id: String
    let animNamespace: Namespace.ID
    
    @Environment(\.colorScheme) var colorScheme
    
    var isCompact  = false
    var isSelected = false
    
    var showFill = true
    
    var action: () -> Void
    @ViewBuilder var label: Label
    
    var body: some View {
        ZStack {
            Button(action: action) {
                label
                    .labelStyle(LuckTabButtonExpandedLabel(id: id, animNamespace: animNamespace, isCompact: isCompact, isSelected: isSelected))
                    .matchedGeometryEffect(id: isSelected ? "sellabel" : "label\(id)", in: animNamespace, properties: .position)
            }
        }
        .frame(width: isCompact ? 50 : nil, height: isCompact ? 50 : nil)
        .padding(!isCompact ? 8 : 0)
        .background {
            Capsule(style: .continuous)
                .fill(
                    colorScheme == .light ?
                    AnyShapeStyle(BackgroundStyle.background) : isCompact ?
                    AnyShapeStyle(BackgroundStyle.background) : AnyShapeStyle(BackgroundStyle.background.quaternary)
                )
                .opacity(showFill ? (!isCompact && isSelected ? 1 : 0) : 0)
                // .animation(isSelected ? .none : .linear(duration: 0.2), value: isSelected)
                .matchedGeometryEffect(id: !isSelected ? "TabButton::\(id)" : "ActiveTabButton", in: animNamespace)
                .frame(width: isCompact ? nil : 90)
                .compositingGroup()
                .shadow(color: .black.opacity(!isSelected ? 0 : 0.1), radius: isCompact ? 0 : 4)
        }
    }
}
#endif
