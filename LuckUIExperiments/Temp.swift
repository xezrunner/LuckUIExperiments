// LuckUIExperiments::Temp.swift - 17/04/2025

import SwiftUI

struct Temp: View {
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero
    
    struct KFAnimProperties {
        var offset: CGFloat = 0
        var scale:  CGFloat = 1
    }
    
    @State var anim = false

    var body: some View {
        HStack(spacing: 24) {
            Image(systemName: "gear")
                .imageScale(.large)
                .padding(12)
                .morphable(shape: .circle)
                .gesture(
                    DragGesture()
                        .onChanged { value in offset1 = value.translation }
                        .onEnded { _ in }
                )
                .phaseAnimator([1, 2], trigger: anim) { content, phase in
                    content
                        .offset(x: phase <= 1 ? 0 : 50)
                }
            
            Image(systemName: "gear")
                .imageScale(.large)
                .padding(12)
                .morphable(shape: .circle)
                .offset(offset2)
                .gesture(
                    DragGesture()
                        .onChanged { value in offset2 = value.translation }
                        .onEnded { _ in }
                )
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.background)
        .safeAreaInset(edge: .bottom) {
            VStack {
                Text("anim: \(anim.description)")
                    .foregroundStyle(.primary)
                
                Button("Toggle anim") { anim.toggle() }
            }
        }
        .morphContainer(background: .primary)
    }
}

#Preview {
    Temp()
}
