// LuckUIExperiments::Temp.swift - 17/04/2025

import SwiftUI

struct Temp: View {
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero
    @State private var offset3: CGSize = .zero
    @State private var offset4: CGSize = .zero

    var body: some View {
        ZStack {
            HStack(spacing: 24) {
                Image(systemName: "gear")
                    .imageScale(.large)
                    .padding(12)
                    .morphable(shape: .circle, intensity: 8)
                    .safeAreaInset(edge: .bottom) { Text("intensity: 8").monospaced().font(.system(size: 7)) }
                    .offset(offset1)
                    .gesture(
                        DragGesture()
                            .onChanged { value in offset1 = value.translation }
                            .onEnded { _ in }
                    )
                
                Image(systemName: "magnifyingglass")
                    .imageScale(.large)
                    .padding(12)
//                    .background(.background, in: .circle)
                    .morphable(shape: .circle, intensity: 8)
                    .safeAreaInset(edge: .bottom) { Text("intensity: 8").monospaced().font(.system(size: 7)) }
                    .offset(offset2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in offset2 = value.translation }
                            .onEnded { _ in }
                    )
                
                Rectangle()
                    .fill(.clear)
                    .frame(maxWidth: 52, maxHeight: 52)
                    .morphable(shape: .roundedRectangle(radius: 0), intensity: 30)
                    .contentShape(.rect)
                    .safeAreaInset(edge: .bottom) { Text("intensity: 30").monospaced().font(.system(size: 7)) }
                    .offset(offset3)
                    .gesture(
                        DragGesture()
                            .onChanged { value in offset3 = value.translation }
                            .onEnded { _ in }
                    )
                
                Rectangle()
                    .fill(.clear)
                    .frame(maxHeight: 52)
                    .morphable(shape: .roundedRectangle(radius: 12.0), intensity: 30)
                    .safeAreaInset(edge: .bottom) { Text("intensity: 30").monospaced().font(.system(size: 7)) }
                    .contentShape(.rect)
                    .offset(offset4)
                    .gesture(
                        DragGesture()
                            .onChanged { value in offset4 = value.translation }
                            .onEnded { _ in }
                    )
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .morphContainer() {
            MeshGradient(width: 3, height: 2, points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                .init(0, 1), .init(0.5, 1), .init(1, 1)
            ], colors: [
                .red, .purple, .indigo,
                .yellow, .green, .mint
            ])
        }
        
        .background(.white)
    }
}

#Preview {
    Temp()
}
