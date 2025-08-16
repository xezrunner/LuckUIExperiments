// LuckUIExperiments::metaball_sdf_common.metal - 16/08/2025
#pragma once

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

enum ShapeType : int8_t {
    Circle = 0,
    Capsule = 1,
    RoundedRectangle = 2
};

struct Entity {
    ShapeType shape_type;
    
    float2 position;
    float2 size;
    float  rounded_rectangle_radius;
    
    float intensity;
};

