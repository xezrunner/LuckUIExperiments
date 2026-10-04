// LuckUIExperiments::XZMorphUI_SDF_Debug.swift - 16/08/2025

import SwiftUI

#if DEBUG
#Preview("Explicit SDF mask") {
    @Previewable @State var intensity: Float = 15

    VStack {
        Color.blue
            .mask {
                SDFMorphMask(entities: [
                    .init(shapeType: .circle, position: .init(x: 12, y: 20),
                          size: .init(width: 60, height: 60), intensity: intensity),
                    .init(shapeType: .capsule, position: .init(x: 78, y: 20),
                          size: .init(width: 60, height: 60), intensity: intensity),
                    .init(shapeType: .roundedRectangle(radius: 100), position: .init(x: 144, y: 20),
                          size: .init(width: 100, height: 60), intensity: intensity)
                ])
            }
            .frame(width: 256, height: 100)

        Slider(value: $intensity, in: 0...60)
        Text("Intensity: \(intensity)")
            .monospaced()
    }
    .padding()
}

#Preview("Nested SDF containers") {
    HStack(spacing: 16) {
        Color.clear
            .frame(width: 60, height: 60)
            .morphable(shape: .circle)
        Color.clear
            .frame(width: 100, height: 60)
            .morphable(shape: .capsule)
            .morphContainer(background: .blue)
    }
    .padding(20)
    .morphContainer(background: .orange)
}
#endif
