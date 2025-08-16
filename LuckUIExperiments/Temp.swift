// LuckUIExperiments::Temp.swift - 17/04/2025

import SwiftUI

struct Temp: View {
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero

    var body: some View {
        HStack(spacing: 24) {
            Image(systemName: "gear")
                .imageScale(.large)
                .padding(12)
                .morphable(shape: .circle)
                .offset(offset1)
                .gesture(
                    DragGesture()
                        .onChanged { value in offset1 = value.translation }
                        .onEnded { _ in }
                )
            
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
        .morphContainer(background: .primary)
    }
}

#Preview {
    Temp()
}
