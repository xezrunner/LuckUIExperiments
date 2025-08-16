// LuckUIExperiments::metaball_sdf.metal - 16/08/2025

#include "metaball_sdf_common.h"
#include "metaball_sdf_shapes.h"

inline float shape_sdf(float2 sample_pos, float2 container_size, Entity entity) {
    switch (entity.shape_type) {
        default:
        case ShapeType::Circle:           return circle           (sample_pos, container_size, entity);
        case ShapeType::Capsule:          return capsule          (sample_pos, container_size, entity);
        case ShapeType::RoundedRectangle: return rounded_rectangle(sample_pos, container_size, entity);
    }
}

// Smooth union (Inigo Quilez)
inline float smoothMin(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

float process_sdf(float2 sample_pos, float2 container_size, const device Entity* entities, uint entity_count) {
    if (entity_count == 0) return 1e9;

    float d = shape_sdf(sample_pos, container_size, entities[0]);

    for (uint i = 1; i < entity_count; ++i) {
        float d2 = shape_sdf(sample_pos, container_size, entities[i]);
        float k = 0.5 * (entities[i - 1].intensity + entities[i].intensity); // simple symmetric-ish pair weight
        d = (k <= 1e-5f) ? min(d, d2) : smoothMin(d, d2, k);
    }
    
    return d;
}

[[stitchable]] half4 metaball_sdf(float2 sample_position, SwiftUI::Layer layer,
                                  float2 size, float entity_count,
                                  device const Entity* entities, int temp // FIXME: for some reason, I need this 'temp' here. I assume SwiftUI's .data() doesn't quite send it the right way?
                                  ) {
    // float2 uv = sample_position / size;
    
    float d = process_sdf(sample_position, size, entities, (int)entity_count);
    
    float aa = fwidth(d);
    float alpha = smoothstep(0.0, aa, -d);
    
    return half4(alpha, alpha, alpha, alpha);
}
