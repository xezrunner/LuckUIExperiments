// LuckUIExperiments::metaball_sdf_shapes.metal - 16/08/2025
#pragma once

#include "metaball_sdf_common.h"

inline float circle(float2 sample_pos, float2 container_size, Entity entity) {
    return length(sample_pos - (entity.position + (entity.size / 2))) - (entity.size.x / 2);
}

// Capsule (axis-aligned; chooses longer axis as the segment, shorter gives radius)
inline float capsule(float2 sample_pos, float2 container_size, Entity entity) {
    float2 pLocal = sample_pos - entity.position;            // origin at top-left of shape
    bool horizontal = entity.size.x >= entity.size.y;
    float r = (horizontal ? entity.size.y : entity.size.x) * 0.5;
    if (horizontal) {
        float2 a = float2(r, entity.size.y * 0.5);
        float2 b = float2(entity.size.x - r, entity.size.y * 0.5);
        float2 pa = pLocal - a;
        float2 ba = b - a;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0f, 1.0f);
        return length(pa - ba * h) - r;
    } else {
        float2 a = float2(entity.size.x * 0.5, r);
        float2 b = float2(entity.size.x * 0.5, entity.size.y - r);
        float2 pa = pLocal - a;
        float2 ba = b - a;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0f, 1.0f);
        return length(pa - ba * h) - r;
    }
}

// Rounded rectangle (uniform corner radius as fraction of min dimension)
inline float rounded_rectangle(float2 sample_pos, float2 container_size, Entity entity) {
    float2 center = entity.position + entity.size * 0.5;
    float2 halfSize = entity.size * 0.5;
    float radius = entity.rounded_rectangle_radius; // tweak factor
    float2 p = sample_pos - center;
    float2 q = abs(p) - (halfSize - float2(radius));
    float outside = length(max(q, 0.0));
    float inside = min(max(q.x, q.y), 0.0);
    return outside + inside - radius;
}
