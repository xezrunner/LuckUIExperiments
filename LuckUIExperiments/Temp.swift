// LuckUIExperiments::Temp.swift - 17/04/2025

import SwiftUI

struct Temp: View {
    @State private var lastLocation: CGSize = .zero
    @State private var location:     CGSize = .zero
    var simpleDrag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                self.location = CGSize(
                    width:  lastLocation.width  + value.translation.width,
                    height: lastLocation.height + (value.translation.height * 0.2)
                )
            }
            .onEnded { value in
                self.lastLocation = self.location
            }
    }
    
    var body: some View {
        MorphContainer {
            HStack {
                MorphView(shape: Circle()) {
                    Circle().fill(.clear)
                }
                
                MorphView(shape: Capsule()) {
                    Capsule().fill(.clear)
                }
                .contentShape(.rect)
                .offset(location)
                .gesture(simpleDrag)
            }
            .frame(height: 50)
            .padding()
        } background: {
            Color.primary
        }
    }
}

#Preview {
    Temp()
}
