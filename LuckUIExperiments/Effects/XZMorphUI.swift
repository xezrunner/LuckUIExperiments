// XZMorphUI::XZMorphUI.swift - 11/04/2025

import SwiftUI

extension EnvironmentValues {
    @Entry var isRequestingMeatball: Bool = false
    @Entry var meatballBlurRadiusMult: CGFloat = 1.0
}

struct MorphContainer<Content: View, Background: View>: View {
    enum MorphMode { case Metal, Blending, Canvas }
    
    public var blurRadiusMult: CGFloat = 1
    
    @State private var mode = MorphMode.Metal
    
    @ViewBuilder public var content:    Content
    @ViewBuilder public var background: Background
    
    var body: some View {
        content
            .contentShape(.rect)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        
#if true // Toggle to debug seeing the mask
            .background {
                background.mask(morphView)
                    .allowsHitTesting(false)
            }
#else
            .overlay {
                morphView
            }
#endif
        
            .clipped()
    }
    
    @ViewBuilder var morphView: some View {
        switch mode {
        case .Metal:    morphView_metal
        case .Blending: morphView_blending
        case .Canvas:   morphView_canvas
        }
    }
    
    // Anti-aliased Metal shader-based solution (best):
    var morphView_metal: some View {
        content
            .environment(\.isRequestingMeatball, true)
            .environment(\.meatballBlurRadiusMult, blurRadiusMult)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        
            .compositingGroup()
            .layerEffect(ShaderLibrary.metaball_blurred(), maxSampleOffset: .zero)
    }
    
    // Entirely built-in constructs with blending modes in SwiftUI.
    // This lacks anti-aliasing and looks crunchy at the edges.
    var morphView_blending: some View {
        content
            .environment(\.isRequestingMeatball, true)
            .environment(\.meatballBlurRadiusMult, blurRadiusMult)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        
            .compositingGroup()
            // .blur(radius: 4 * blurRadiusMult)
            .overlay {
                ZStack {
                    Color(white: 0.5)
                        .blendMode(.colorBurn)
                    Color(white: 1.0)
                        .blendMode(.colorDodge)
                }
                .allowsHitTesting(false)
            }
        
            .compositingGroup()
            .blendMode(.darken)
            .colorInvert()
            .luminanceToAlpha()
        
            // .clipped()
    }
    
    // This is incompatible with .matchedGeometryEffect() and similar (animations/transitions?) that rely on internal SwiftUI positioning.
    // These elements end up have a canonical position of [global 0;0].
    var morphView_canvas: some View {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: 0.5, color: .white))
            
            if let symbol = context.resolveSymbol(id: 0) {
                context.draw(symbol, at: CGPoint(x: size.width / 2, y: size.height / 2))
            }
        } symbols: {
            content
                .environment(\.isRequestingMeatball, true)
                .environment(\.meatballBlurRadiusMult, blurRadiusMult)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tag(0)
        }
    }
}

struct MorphView<Content: View, Shape: View>: View {
    @Environment(\.isRequestingMeatball)   private var isRequestingMeatball
    @Environment(\.meatballBlurRadiusMult) private var meatballBlurRadiusMult
    
    public var blurRadius: CGFloat = 4.0
    
    @ViewBuilder public var content: Content
    public var shape: Shape?
    
    var body: some View {
        if !isRequestingMeatball {
            content
        } else {
            shape // NOTE: will be 'content' if shape is nil! Should probably not do this, as we wouldn't want to render 'content' twice!
                .blur(radius: !isRequestingMeatball ? 0 : blurRadius * meatballBlurRadiusMult)
        }
    }
}

extension MorphView {
    init(shape: Shape, blurRadius: CGFloat = 4.0, @ViewBuilder content: @escaping () -> Content) {
        self.blurRadius = blurRadius
        self.content = content()
        self.shape = shape
    }
    
    init(blurRadius: CGFloat = 4.0, @ViewBuilder content: @escaping () -> Content, @ViewBuilder shape: @escaping () -> Shape) {
        self.blurRadius = blurRadius
        self.content = content()
        self.shape = shape()
    }
}

extension MorphView where Shape == Content {
    init(blurRadius: CGFloat = 4.0, @ViewBuilder content: @escaping () -> Content) {
        self.blurRadius = blurRadius
        self.content = content()
        self.shape = content()
    }
}
