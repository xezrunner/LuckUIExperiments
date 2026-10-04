from pathlib import Path
import re
import subprocess

# NOTE: Run from the repository root. Compile the actual record and shape code, without xcodebuild.
root = Path.cwd()
swift_source = (root / "LuckUIExperiments/Effects/XZMorphUI_SDF/XZMorphUI_SDF.swift").read_text()
model = swift_source.split("struct SDFMorphMask")[0]
packing = re.search(r"    private var entityData: Data \{(.*?)\n    \}", swift_source, re.S).group(1)
shader_dir = root / "LuckUIExperiments/Shaders/SDF_morph"
metal_source = "\n".join((shader_dir / name).read_text() for name in [
    "metaball_sdf_common.h", "metaball_sdf_shapes.h", "metaball_sdf.metal"
])
metal_source = re.sub(r'#include "[^"\n]+"\n', "", metal_source)
metal_source = metal_source.split("// NOTE: Shader.Argument.data")[0]
metal_source += """
kernel void check_sdf(device const Entity* entities [[buffer(0)]],
                      device const float2* samples [[buffer(1)]],
                      device float* results [[buffer(2)]],
                      uint index [[thread_position_in_grid]]) {
    results[index] = shape_sdf(samples[index], entities[index]);
}
kernel void check_union(device const Entity* entities [[buffer(0)]],
                        device float* results [[buffer(1)]],
                        uint index [[thread_position_in_grid]]) {
    results[index] = process_sdf(float2(70, 40), entities + index * 2, 2);
}
"""
swift = r'''
import Foundation
import Metal

MODEL

func entityData(_ entities: [SDFMorphableEntity]) -> Data {
PACKING
}

precondition(MemoryLayout<SDFGPUEntity>.size == 32)
precondition(MemoryLayout<SDFGPUEntity>.stride == 32)
precondition(MemoryLayout<SDFGPUEntity>.alignment == 16)
precondition(MemoryLayout<SDFGPUEntity>.offset(of: \.parameters) == 16)

var maskEntity = SDFMorphableEntity(shapeType: .roundedRectangle(radius: 100),
                                    position: CGPoint(x: 10, y: 20),
                                    size: CGSize(width: 40, height: 40), intensity: -10)
var invalidPosition = maskEntity
invalidPosition.position.x = .nan
let zeroSize = SDFMorphableEntity(shapeType: .capsule, position: .zero, size: .zero, intensity: 15)
let maskData = entityData([maskEntity, invalidPosition, zeroSize])
precondition(maskData.count == 32, "invalid geometry must be omitted")
maskData.withUnsafeBytes {
    let floats = Array($0.bindMemory(to: Float.self))
    precondition(floats == [10, 20, 40, 40, 2, 20, 0, 0], "packed bounds, radius and intensity")
}
maskEntity.size = .zero
precondition(entityData([maskEntity]).isEmpty, "updated inputs must produce updated data")
precondition(entityData([]).isEmpty, "empty mask data")

private struct Case {
    var name: String
    var entity: SDFGPUEntity
    var sample: SIMD2<Float>
    var expected: Float
}

private func entity(_ tag: Float, _ size: SIMD2<Float>, radius: Float = 0,
            intensity: Float = 0, origin: SIMD2<Float> = SIMD2(10, 20)) -> SDFGPUEntity {
    SDFGPUEntity(bounds: SIMD4(origin.x, origin.y, size.x, size.y),
                 parameters: SIMD4(tag, radius, intensity, 0))
}

private let cases: [Case] = [
    Case(name: "square capsule center", entity: entity(1, SIMD2(40, 40)), sample: SIMD2(30, 40), expected: -20),
    Case(name: "square capsule edge", entity: entity(1, SIMD2(40, 40)), sample: SIMD2(50, 40), expected: 0),
    Case(name: "square capsule outside", entity: entity(1, SIMD2(40, 40)), sample: SIMD2(52, 40), expected: 2),
    Case(name: "horizontal capsule center", entity: entity(1, SIMD2(100, 40)), sample: SIMD2(60, 40), expected: -20),
    Case(name: "horizontal capsule end", entity: entity(1, SIMD2(100, 40)), sample: SIMD2(110, 40), expected: 0),
    Case(name: "vertical capsule end", entity: entity(1, SIMD2(40, 100)), sample: SIMD2(30, 120), expected: 0),
    Case(name: "zero capsule", entity: entity(1, .zero), sample: SIMD2(10, 20), expected: 0),
    Case(name: "one zero capsule dimension", entity: entity(1, SIMD2(0, 40)), sample: SIMD2(10, 40), expected: 0),
    Case(name: "oversized radius clamps", entity: entity(2, SIMD2(80, 40), radius: 100), sample: SIMD2(10, 20), expected: sqrt(800) - 20),
    Case(name: "negative radius clamps", entity: entity(2, SIMD2(80, 40), radius: -100), sample: SIMD2(10, 20), expected: 0),
    Case(name: "circle fits smaller dimension", entity: entity(0, SIMD2(80, 40)), sample: SIMD2(50, 40), expected: -20),
    Case(name: "unknown shape defaults to circle", entity: entity(127, SIMD2(40, 40)), sample: SIMD2(30, 40), expected: -20)
]

let device = MTLCreateSystemDefaultDevice()!
let library = try device.makeLibrary(source: #"""
METAL
"""#, options: nil)
let queue = device.makeCommandQueue()!
let command = queue.makeCommandBuffer()!

func buffer<T>(_ values: [T]) -> MTLBuffer {
    values.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)! }
}

let resultBuffer = device.makeBuffer(length: cases.count * MemoryLayout<Float>.stride, options: .storageModeShared)!
let encoder = command.makeComputeCommandEncoder()!
encoder.setComputePipelineState(try device.makeComputePipelineState(function: library.makeFunction(name: "check_sdf")!))
encoder.setBuffer(buffer(cases.map(\.entity)), offset: 0, index: 0)
encoder.setBuffer(buffer(cases.map(\.sample)), offset: 0, index: 1)
encoder.setBuffer(resultBuffer, offset: 0, index: 2)
encoder.dispatchThreads(MTLSize(width: cases.count, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
encoder.endEncoding()

let unionBuffer = device.makeBuffer(length: 2 * MemoryLayout<Float>.stride, options: .storageModeShared)!
let unionEncoder = command.makeComputeCommandEncoder()!
unionEncoder.setComputePipelineState(try device.makeComputePipelineState(function: library.makeFunction(name: "check_union")!))
unionEncoder.setBuffer(buffer([
    entity(0, SIMD2(40, 40), origin: SIMD2(30, 20)),
    entity(0, SIMD2(40, 40), origin: SIMD2(70, 20)),
    entity(0, SIMD2(40, 40), intensity: 20, origin: SIMD2(30, 20)),
    entity(0, SIMD2(40, 40), intensity: 20, origin: SIMD2(70, 20))
]), offset: 0, index: 0)
unionEncoder.setBuffer(unionBuffer, offset: 0, index: 1)
unionEncoder.dispatchThreads(MTLSize(width: 2, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
unionEncoder.endEncoding()
command.commit()
command.waitUntilCompleted()
precondition(command.status == .completed, String(describing: command.error))

let results = resultBuffer.contents().bindMemory(to: Float.self, capacity: cases.count)
for (index, test) in cases.enumerated() {
    precondition(results[index].isFinite && abs(results[index] - test.expected) < 0.001,
                 "\(test.name): got \(results[index]), expected \(test.expected)")
}
let unions = unionBuffer.contents().bindMemory(to: Float.self, capacity: 2)
precondition(abs(unions[0]) < 0.001, "zero-intensity hard union")
precondition(abs(unions[1] + 5) < 0.001, "smooth union connects touching shapes")
print("PASS: 32-byte Swift/GPU layout, CPU input packing, \(cases.count) GPU geometry cases, hard and smooth union")
'''
swift = swift.replace("MODEL", model).replace("PACKING", packing).replace("METAL", metal_source)
subprocess.run(["xcrun", "swift", "-"], input=swift, text=True, check=True)
