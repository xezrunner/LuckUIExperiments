// XZMorphUI::XZMorphUI.swift - 11/04/2025

import SwiftUI

extension EnvironmentValues {
    @Entry var isRequestingMeatball: Bool = false
    @Entry var meatballBlurRadiusMult: CGFloat = 1.0
}

struct MorphContainer<Content: View, Background: View>: View {
    public var blurRadiusMult: CGFloat = 1
    
    @ViewBuilder public var content:    Content
    @ViewBuilder public var background: Background
    
    var body: some View {
        content
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                background.mask(meatball_blending)
//                background.mask(meatball_layer)
                .allowsHitTesting(false)
            }
            .clipped()
    }
    
    var meatball_layer: some View {
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
    
    var meatball_blending: some View {
        content
            .environment(\.isRequestingMeatball, true)
            .environment(\.meatballBlurRadiusMult, blurRadiusMult)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        
            .compositingGroup()
//            .blur(radius: 4 * blurRadiusMult)
//            .drawingGroup()
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
        
//            .clipped()
    }
}

struct MorphView<Content: View>: View {
    @Environment(\.isRequestingMeatball)   private var isRequestingMeatball
    @Environment(\.meatballBlurRadiusMult) private var meatballBlurRadiusMult
    
    public var blurRadius: CGFloat = 4.0

    @ViewBuilder public var content: Content    
    
    var body: some View {
        if !isRequestingMeatball {
            content
        } else {
            Group {
                if isRequestingMeatball {
                    Color.black
                        .padding(blurRadius * meatballBlurRadiusMult / 2.5)
                        .blur(radius: blurRadius * meatballBlurRadiusMult)
                }
            }
            .allowsHitTesting(false)
        }
    }
}
