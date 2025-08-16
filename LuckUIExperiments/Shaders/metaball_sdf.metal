// LuckUIExperiments::metaball_sdf.metal - 16/08/2025

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

struct Entity {
    float2 position;
    float2 size;
};

inline float circle(float2 sample_pos, float2 container_size, Entity entity) {
    return length(sample_pos - (entity.position + (entity.size / 2))) - (entity.size.x / 2);
}

// Smooth union (Inigo Quilez)
inline float smoothMin(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

// Anti-aliased metaball blending
float metaballSDF(float2 sample_pos, float2 container_size, const device Entity* entities, uint entityCount, float k) {
    if (entityCount == 0) return 1e9;
    
    float d = circle(sample_pos, container_size, entities[0]);
    
    for (uint i = 1; i < entityCount; ++i) {
        d = smoothMin(d, circle(sample_pos, container_size, entities[i]), k);
    }
    
    return d;
}

[[stitchable]] half4 metaball_sdf(float2 sample_position, SwiftUI::Layer layer,
                                  float2 size, float entity_count,
                                  device const Entity* entities, int temp // FIXME: for some reason, I need this 'temp' here. I assume SwiftUI's .data() doesn't quite send it the right way?
                                  ) {
    // float2 uv = sample_position / size;
    
    float k = 20.0; // smoothness
    float d = metaballSDF(sample_position, size, entities, (int)entity_count, k);
    
    float aa = fwidth(d);
    float alpha = smoothstep(0.0, aa, -d);
    
    return half4(alpha, alpha, alpha, alpha);
}
