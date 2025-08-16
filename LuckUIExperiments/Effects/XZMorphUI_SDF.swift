// LuckUIExperiments::XZMorphUI_SDF.swift - 16/08/2025

import SwiftUI

enum SDFShapeType: Equatable {
    typealias RawValue = Int8
    
    case circle
    case capsule
    case roundedRectangle(radius: Float)
    
    var rawValue: RawValue {
        switch self {
        case .circle: 0
        case .capsule: 1
        case .roundedRectangle: 2
        }
    }
}

struct SDFMorphableEntity: Equatable {
    var shapeType: SDFShapeType.RawValue
    
    var position:  SIMD2<Float>
    var size:      SIMD2<Float>
    var roundedRectangleRadius: Float
    
    var intensity: Float
}
extension SDFMorphableEntity {
    init(shapeType: SDFShapeType, position: CGPoint, size: CGSize, intensity: Float) {
        self.shapeType = shapeType.rawValue
        
        self.position = .init(Float(position.x), Float(position.y))
        self.size = .init(Float(size.width), Float(size.height))
        
        switch shapeType {
            case .roundedRectangle(let radius): self.roundedRectangleRadius = radius
            default:                            self.roundedRectangleRadius = 0
        }
        
        self.intensity = intensity
    }
    
    internal static var `default` = SDFMorphableEntity(shapeType: .circle, position: .zero, size: .zero, intensity: 0)
}

struct SDFMorphableInfoPrefKey: PreferenceKey {
    static var defaultValue: [SDFMorphableEntity] = []
    static func reduce(value: inout Value, nextValue: () -> Value) { value.append(contentsOf: nextValue()) }
}

struct SDFMorphableViewModifier: ViewModifier {
    public static let DEFAULT_INTENSITY: Float = 15
    
    @State var shape: SDFShapeType
    @State var intensity: Float = DEFAULT_INTENSITY
    
    @State private var entity: SDFMorphableEntity = .default
    
    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named("SDFMorphContainer")) }, action: {
                entity = .init(shapeType: shape, position: $0.origin, size: $0.size, intensity: intensity)
            })
            .preference(key: SDFMorphableInfoPrefKey.self, value: [entity])
    }
}

struct SDFMorphContainer<Content: View, Background: View>: View {
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
            }
            .padding()
        }
    }
}

extension SDFMorphContainer {
    init(@ViewBuilder content: @escaping () -> Content) where Background == _ShapeView<Rectangle, BackgroundStyle> {
        self.content = content
        self.background = { Rectangle().fill(.background) }
    }
    
    init(@ViewBuilder content: @escaping () -> Content, background: Color) where Background == Color {
        self.content = content
        self.background = { background }
    }
}

extension View {
    func morphable(shape: SDFShapeType, intensity: Float = SDFMorphableViewModifier.DEFAULT_INTENSITY) -> some View {
        self.modifier(SDFMorphableViewModifier(shape: shape, intensity: intensity))
    }
    
    func morphContainer<Background: View>(@ViewBuilder background: @escaping () -> Background) -> some View {
        SDFMorphContainer(content: { self }, background: background)
    }
    
    func morphContainer(background: Color) -> some View {
        SDFMorphContainer(content: { self }, background: background)
    }
}

#Preview {
    @Previewable @State var xOffset: CGFloat = 0
    
    VStack {
        HStack {
            Circle().fill(.clear)
                .morphable(shape: .circle)
                .offset(x: xOffset)
            
            Rectangle().fill(.clear)
                .morphable(shape: .roundedRectangle(radius: 8))
        }
        
        Circle().fill(.clear)
            .morphable(shape: .circle)
            .offset(y: -xOffset)
    }
    .frame(maxHeight: 60)
    .padding()
    .opacity(0.3)
    .safeAreaInset(edge: .bottom) {
        Slider(value: $xOffset, in: -100...100)
            .padding()
    }
    .morphContainer(background: .red)
//    .background(.green)
}
