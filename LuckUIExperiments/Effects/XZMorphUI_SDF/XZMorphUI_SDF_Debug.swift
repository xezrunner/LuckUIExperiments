// LuckUIExperiments::XZMorphUI_SDF_Debug.swift - 16/08/2025

import SwiftUI

#if DEBUG
extension SDFMorphContainer {
    internal var debugView: some View {
        VStack(alignment: .leading) {
            Group {
                Text("Entities (.morphable()) (\(entities.count)):")
                List(0..<entities.count, id: \.self) { index in
                    let it = entities[index]
                    
                    Section("Entity #\(index)") {
                        Stepper("shape: \(SDFShapeType.name(for: entities[index].shapeType))",
                                value: Binding(get: { it.shapeType }, set: { entities[index].shapeType = $0 }), step: 1)
                        
                        Text("pos:  [\(it.position.x); \(it.position.y)]")
                        Text("size: [\(it.size.x); \(it.size.y)]")
                        
                        if it.shapeType == 2 {
                            Stepper("radius: \(it.roundedRectangleRadius)",
                                    value: Binding(get: { it.roundedRectangleRadius }, set: { entities[index].roundedRectangleRadius = $0 }),
                                    in: 0...100, step: 1)
                        }
                        
                        Stepper("intensity: \(it.intensity)",
                                value: Binding(get: { it.intensity }, set: { entities[index].intensity = $0 }),
                                in: 0...100, step: 1)
                    }
                    .listRowBackground(Color.primary.opacity(0.15))
                }
                .scrollContentBackground(.hidden)
                .listSectionSpacing(0)
                .listStyle(.plain)
                
                Divider()
                
                Text("SDFMorphableEntity stride: \(MemoryLayout<SDFMorphableEntity>.stride)")
                Text("SIMD2<Float> stride: \(MemoryLayout<SIMD2<Float>>.stride)")
                Text("Float stride: \(MemoryLayout<Float>.stride)")
            }
            .monospaced()
            .foregroundStyle(.primary)
            .font(.system(size: 13))
        }
        .padding()
    }
}
#endif
