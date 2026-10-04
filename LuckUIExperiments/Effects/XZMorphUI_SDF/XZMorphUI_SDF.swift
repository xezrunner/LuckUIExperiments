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

// NOTE: Position is the top-left origin in mask-local points; radius and intensity are also in points.
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
}

// NOTE: Two float4 values match Entity in metaball_sdf_common.h without Swift enum or padding bytes.
private struct SDFGPUEntity {
    var bounds: SIMD4<Float>
    var parameters: SIMD4<Float>
}

struct SDFMorphMask: View {
    var entities: [SDFMorphableEntity]

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(ShaderLibrary.metaball_sdf(.data(entityData), .float(1 / displayScale)))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var entityData: Data {
        var gpuEntities: [SDFGPUEntity] = []
        gpuEntities.reserveCapacity(entities.count)
        for entity in entities {
            guard entity.position.x.isFinite, entity.position.y.isFinite,
                  entity.size.x.isFinite, entity.size.y.isFinite,
                  entity.size.x > 0, entity.size.y > 0 else { continue }

            let maxRadius = min(entity.size.x, entity.size.y) * 0.5
            let radius = entity.roundedRectangleRadius.isFinite
                ? min(max(entity.roundedRectangleRadius, 0), maxRadius) : 0
            let intensity = entity.intensity.isFinite ? max(entity.intensity, 0) : 0
            gpuEntities.append(SDFGPUEntity(
                bounds: SIMD4(entity.position.x, entity.position.y, entity.size.x, entity.size.y),
                parameters: SIMD4(Float(entity.shapeType), radius, intensity, 0)
            ))
        }
        return gpuEntities.withUnsafeBytes { Data($0) }
    }
}

struct SDFMorphableBounds {
    var shape: SDFShapeType
    var intensity: Float
    var anchor: Anchor<CGRect>
}

struct SDFMorphableInfoPrefKey: PreferenceKey {
    static var defaultValue: [SDFMorphableBounds] { [] }
    static func reduce(value: inout Value, nextValue: () -> Value) { value.append(contentsOf: nextValue()) }
}

struct SDFMorphableViewModifier: ViewModifier {
    public static let DEFAULT_INTENSITY: Float = 15
    
    var shape: SDFShapeType
    var intensity: Float = DEFAULT_INTENSITY
    
    func body(content: Content) -> some View {
        content
            .anchorPreference(key: SDFMorphableInfoPrefKey.self, value: .bounds) {
                [SDFMorphableBounds(shape: shape, intensity: intensity, anchor: $0)]
            }
    }
}

struct SDFMorphContainer<Content: View, Background: View>: View {
    @ViewBuilder var content:    () -> Content
    @ViewBuilder var background: () -> Background
    
    var body: some View {
        content()
            .backgroundPreferenceValue(SDFMorphableInfoPrefKey.self) { bounds in
                GeometryReader { geometry in
                    background()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .mask {
                            SDFMorphMask(entities: bounds.map { item in
                                let frame = geometry[item.anchor]
                                return SDFMorphableEntity(
                                    shapeType: item.shape,
                                    position: frame.origin,
                                    size: frame.size,
                                    intensity: item.intensity
                                )
                            })
                        }
                        .allowsHitTesting(false)
                }
            }
            // NOTE: A nested container consumes its anchors so outer containers render only their own shapes.
            .transformPreference(SDFMorphableInfoPrefKey.self) { $0.removeAll() }
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
    
    func morphContainer() -> some View {
        SDFMorphContainer(content: { self })
    }
    
    func morphContainer<Background: View>(@ViewBuilder background: @escaping () -> Background) -> some View {
        SDFMorphContainer(content: { self }, background: background)
    }
    
    func morphContainer(background: Color) -> some View {
        SDFMorphContainer(content: { self }, background: background)
    }
}

#Preview {
    @Previewable @State var offset: CGFloat = 0
    @Previewable @State var color : Color = .red
    
    VStack {
        HStack {
            Circle().fill(.clear)
                .morphable(shape: .circle)
                .offset(x: offset)
            
            Rectangle().fill(.clear)
                .morphable(shape: .roundedRectangle(radius: 8))
        }
        
        Circle().fill(.clear)
            .morphable(shape: .circle)
            .offset(y: -offset)
    }
    .frame(maxHeight: 60)
    .padding(64)
    .border(color)
    .opacity(0.3)
    .safeAreaInset(edge: .bottom) {
        VStack(alignment: .leading, spacing: 0) {
            Text("Testing Offsets: \(offset)")
            Slider(value: $offset, in: -200...200)
            
            ColorPicker("Color", selection: $color)
        }
        .padding()
        .monospaced()
    }
    .morphContainer(background: color)
//    .background(.green)
}
