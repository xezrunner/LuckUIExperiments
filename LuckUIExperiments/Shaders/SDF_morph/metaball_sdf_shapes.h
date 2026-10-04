// LuckUIExperiments::metaball_sdf_shapes.metal - 16/08/2025
#pragma once

#include "metaball_sdf_common.h"

inline float circle(float2 sample_pos, Entity entity) {
    float2 size = entity.bounds.zw;
    float2 center = entity.bounds.xy + size * 0.5f;
    return length(sample_pos - center) - min(size.x, size.y) * 0.5f;
}

inline float capsule(float2 sample_pos, Entity entity) {
    float2 half_size = entity.bounds.zw * 0.5f;
    float radius = min(half_size.x, half_size.y);
    float2 p = sample_pos - (entity.bounds.xy + half_size);
    // NOTE: Distance to an axis-aligned segment, including a zero-length segment for square capsules.
    float2 q = max(abs(p) - (half_size - radius), 0.0f);
    return length(q) - radius;
}

inline float rounded_rectangle(float2 sample_pos, Entity entity) {
    float2 halfSize = entity.bounds.zw * 0.5f;
    float2 center = entity.bounds.xy + halfSize;
    float radius = clamp(entity.parameters.y, 0.0f, min(halfSize.x, halfSize.y));
    float2 p = sample_pos - center;
    float2 q = abs(p) - (halfSize - float2(radius));
    float outside = length(max(q, 0.0));
    float inside = min(max(q.x, q.y), 0.0);
    return outside + inside - radius;
}
