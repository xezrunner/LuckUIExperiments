// LuckUIExperiments::XZMorphUI_SDF.swift - 16/08/2025

import SwiftUI

struct SDFMorphableEntity: Equatable {
    var position: SIMD2<Float>
    var size:     SIMD2<Float>
}
extension SDFMorphableEntity {
    init(position: CGPoint, size: CGSize) {
        self.position = .init(Float(position.x), Float(position.y))
        self.size = .init(Float(size.width), Float(size.height))
    }
}

struct SDFMorphableInfoPrefKey: PreferenceKey {
    static var defaultValue: [SDFMorphableEntity] = []
    static func reduce(value: inout Value, nextValue: () -> Value) { value.append(contentsOf: nextValue()) }
}

struct SDFMorphableViewModifier: ViewModifier {
    @State var entity: SDFMorphableEntity = .init(position: .zero, size: .zero)
    
    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named("SDFMorphContainer")) }, action: {
                entity = .init(position: $0.origin, size: $0.size)
            })
            .preference(key: SDFMorphableInfoPrefKey.self, value: [entity])
    }
}

struct SDFMorphContainer<Content: View, Background: View>: View {
    @State private var progress = 0.0
    
    @State private var entities: [SDFMorphableEntity] = []
    
    @ViewBuilder var content:    () -> Content
    @ViewBuilder var background: () -> Background
    
    @State private var contentGeoInfo: CGRect = .zero
    
    var body: some View {
        ZStack {
            content()
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .local) }, action: { contentGeoInfo = $0 })
                .onPreferenceChange(SDFMorphableInfoPrefKey.self) { newValue in
                    entities = newValue
                }
                .coordinateSpace(name: "SDFMorphContainer")
        }
        .background {
            background()
                .mask {
                    Rectangle()
                        .layerEffect(
                            ShaderLibrary.metaball_sdf(.float2(contentGeoInfo.size.width, contentGeoInfo.size.height), .float(Float(entities.count)),
                                                       .data(Data(bytes: entities, count: entities.count * MemoryLayout<SDFMorphableEntity>.stride)),
                                                      )
                            , maxSampleOffset: .zero)
                }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading) {
                Group {
                    Text("Collected entities (\(entities.count)):")
                    ForEach(0..<entities.count, id: \.self) { index in
                        let it = entities[index]
                        Text("  - \(index): pos: \(it.position.debugDescription)  size: \(it.size.debugDescription)")
                    }
                    
                    Divider()
                    
                    Text("SDFMorphableEntity stride: \(MemoryLayout<SDFMorphableEntity>.stride)")
                }
                .monospaced()
                .font(.system(size: 14))
                
                Slider(value: $progress, in: -100...100)
            }
            .padding()
        }
    }
}

extension SDFMorphContainer where Background == _ShapeView<Rectangle, BackgroundStyle> {
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.background = { Rectangle().fill(.background) }
    }
}

extension View {
    func morphable() -> some View {
        self.modifier(SDFMorphableViewModifier())
    }
    
    func morphContainer() -> some View {
        SDFMorphContainer {
            self
        }
    }
}

#Preview {
    @Previewable @State var xOffset: CGFloat = 0
    
    HStack {
        Circle().fill(.red)
            .morphable()
            .offset(x: xOffset)
        
        Circle().fill(.red)
            .morphable()
    }
    .opacity(0.3)
    .frame(maxHeight: 60)
    .safeAreaInset(edge: .bottom) {
        Slider(value: $xOffset, in: -100...100)
            .padding()
    }
    .morphContainer()
    .background(.green)
}
