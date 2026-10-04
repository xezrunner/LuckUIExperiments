// LuckUIExperiments::metaball_sdf.metal - 16/08/2025

#include "metaball_sdf_common.h"
#include "metaball_sdf_shapes.h"

inline float shape_sdf(float2 sample_pos, Entity entity) {
    switch (int(entity.parameters.x)) {
        default:
        case ShapeType::Circle:           return circle           (sample_pos, entity);
        case ShapeType::Capsule:          return capsule          (sample_pos, entity);
        case ShapeType::RoundedRectangle: return rounded_rectangle(sample_pos, entity);
    }
}

// NOTE: Polynomial smooth union (Inigo Quilez), with hard union handled by the caller at zero intensity.
inline float smoothMin(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

float process_sdf(float2 sample_pos, const device Entity* entities, uint entity_count) {
    float d = shape_sdf(sample_pos, entities[0]);

    for (uint i = 1; i < entity_count; ++i) {
        float d2 = shape_sdf(sample_pos, entities[i]);
        float k = 0.5f * entities[i - 1].parameters.z + 0.5f * entities[i].parameters.z;
        d = (k <= 1e-5f) ? min(d, d2) : smoothMin(d, d2, k);
    }
    
    return d;
}

// NOTE: Shader.Argument.data binds a device pointer followed by an int byte length.
[[stitchable]] half4 metaball_sdf(float2 sample_position, device const void* data,
                                int size_in_bytes, float pixel_size) {
    if (size_in_bytes < int(sizeof(Entity))) return half4(0.0h);
    device const Entity* entities = static_cast<device const Entity*>(data);
    uint entity_count = uint(size_in_bytes) / uint(sizeof(Entity));
    float d = process_sdf(sample_position, entities, entity_count);

    float aa = max(fwidth(d), pixel_size);
    float alpha = smoothstep(-0.5f * aa, 0.5f * aa, -d);
    
    return half4(alpha, alpha, alpha, alpha);
}
