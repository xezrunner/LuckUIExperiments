// LuckUIExperiments::metaball_sdf_common.metal - 16/08/2025
#pragma once

#include <metal_stdlib>
using namespace metal;

enum ShapeType {
    Circle = 0,
    Capsule = 1,
    RoundedRectangle = 2
};

struct Entity {
    // NOTE: Origin x/y and size width/height, all in points.
    float4 bounds;
    // NOTE: Shape tag, corner radius, union intensity, and reserved zero padding.
    float4 parameters;
};

static_assert(sizeof(Entity) == 32, "Entity must match SDFGPUEntity's two SIMD4<Float> values");
