// LuckUIExperiments::metaball_blurred.metal - 16/04/2025

#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

[[stitchable]] half4 metaball_blurred(float2 sample_position, SwiftUI::Layer layer) {
        half4 s = layer.sample(sample_position);
        // Anti-aliased alpha thresholding:
        constexpr half threshold = 0.5;
    
        float w = fwidth(s.a);
        half edge = w * 0.5;
        
        float alpha = smoothstep(threshold - edge, threshold + edge, s.a);
        return half4(1.0, 1.0, 1.0, alpha);
}
