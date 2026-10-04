from pathlib import Path
import re
import subprocess

# NOTE: Exercise the actual SwiftUI tracks on macOS without an iOS app host or a second module.
source = Path('LuckUIExperiments/Controls/LuckTabBar.swift').read_text()
# NOTE: Timeline sampling cannot catch the live animator resetting when its initial value changes.
initial_value = re.search(r'KeyframeAnimator\(initialValue:\s*(\w+)\s*,', source)
assert initial_value, 'The live animator must receive a stable initial frame, not the changing target'
initial_name = re.escape(initial_value.group(1))
assert re.search(r'@State private var ' + initial_name + r': LuckTabBarFrame', source), \
    'Capture the initial frame once for the lifetime of the bar'
assert re.search(r'_' + initial_name + r'\s*=\s*State\(initialValue: LuckTabBarFrame\(expanded: isExpanded\)\)', source), \
    'Preserve the caller-requested initial presentation without animating an entrance'
tracks = source[source.index('    @KeyframesBuilder'):source.index('\n}\n\nprivate struct LuckTabBarFrame')]
tracks = tracks.replace('private func tracks(from value:', 'func tracks(expanded isExpanded: Bool, from value:')
frame = source[source.index('private struct LuckTabBarFrame'):].replace('private struct', 'struct')
label_offset = re.search(r'\.offset\(x: (direction \* frame\.labelOffset[^\n]+)\)', source).group(1)
label_scale = re.search(r'\.scaleEffect\((max\(0\.001, [^\n]+)\)', source).group(1)
strip_offset = re.search(r'\.offset\(x: (direction \* \(\(buttonSize[^\n]+)\)', source).group(1)
rendering = '''
func renderedLabels(_ frame: LuckTabBarFrame, expanded isExpanded: Bool, direction: CGFloat) -> [(x: CGFloat, scale: CGFloat)] {
    let buttonSize: CGFloat = 48
    return (0..<5).map { index in
        let order = CGFloat(index + 1)
        let baseX = 4 + (CGFloat(index) + 0.5) * (390 - 8) / 5
        return (baseX + LABEL_OFFSET + STRIP_OFFSET, LABEL_SCALE)
    }
}
'''.replace('LABEL_OFFSET', label_offset).replace('STRIP_OFFSET', strip_offset).replace('LABEL_SCALE', label_scale)
checks = r'''
let fields: [KeyPath<LuckTabBarFrame, CGFloat>] = [
    \.expansion, \.nudge, \.squeeze, \.buttonOffset, \.buttonScale,
    \.searchOffset, \.searchScale, \.visibility, \.labelScale, \.labelOffset, \.labelExponent
]
func timeline(_ expanded: Bool, from initial: LuckTabBarFrame) -> KeyframeTimeline<LuckTabBarFrame> {
    KeyframeTimeline(initialValue: initial) { tracks(expanded: expanded, from: initial) }
}
var samples = 0
var reversals = 0
var hiddenResets = 0
var cycles = 0
var maxPositionJump: CGFloat = 0
func sample(_ animation: KeyframeTimeline<LuckTabBarFrame>, expanded: Bool) {
    precondition(animation.duration.isFinite && animation.duration > 0)
    for time in Array(stride(from: 0.0, to: animation.duration, by: 1.0 / (120 * speed))) + [animation.duration] {
        let value = animation.value(time: time)
        for field in fields { precondition(value[keyPath: field].isFinite, "Non-finite animation at \(time)") }
        precondition(value.buttonScale > 0 && value.searchScale > 0, "Invalid rendered scale")
        for direction: CGFloat in [-1, 1] {
            for label in renderedLabels(value, expanded: expanded, direction: direction) {
                precondition(label.x.isFinite && label.scale.isFinite && label.scale > 0, "Invalid rendered label")
            }
        }
        samples += 1
    }
    let end = animation.value(time: animation.duration)
    var expected = LuckTabBarFrame(expanded: expanded)
    expected.labelOffset = expanded ? 0 : -10
    for field in fields {
        precondition(abs(end[keyPath: field] - expected[keyPath: field]) < 0.001, "Wrong endpoint for \(field)")
    }
}
func reverse(_ current: LuckTabBarFrame, wasExpanded: Bool) -> KeyframeTimeline<LuckTabBarFrame> {
    let animation = timeline(!wasExpanded, from: current)
    let start = animation.value(time: 0)
    let resetsHiddenLabels = !wasExpanded && current.visibility <= 0.001
    for field in fields {
        if resetsHiddenLabels && field == \.labelOffset { continue }
        precondition(abs(start[keyPath: field] - current[keyPath: field]) < 0.001, "Frame jump on reversal: \(field)")
    }
    if resetsHiddenLabels {
        precondition(start.labelOffset == -30, "Hidden labels must restart their full entrance")
        hiddenResets += 1
    }
    if current.visibility > 0.001 {
        for direction: CGFloat in [-1, 1] {
            let before = renderedLabels(current, expanded: wasExpanded, direction: direction)
            let after = renderedLabels(start, expanded: !wasExpanded, direction: direction)
            for (old, new) in zip(before, after) {
                maxPositionJump = max(maxPositionJump, abs(old.x - new.x))
                precondition(abs(old.x - new.x) < 0.001, "Visible label jumps on reversal")
                precondition(abs(old.scale - new.scale) < 0.001, "Visible label scale jumps on reversal")
            }
        }
    }
    reversals += 1
    sample(animation, expanded: !wasExpanded)
    return animation
}
func checkImmediateProgress(_ animation: KeyframeTimeline<LuckTabBarFrame>, fields: [KeyPath<LuckTabBarFrame, CGFloat>]) {
    let start = animation.value(time: 0)
    let early = animation.value(time: 0.01 / speed)
    for field in fields {
        precondition(abs(early[keyPath: field] - start[keyPath: field]) > 0.00001,
                     "Interrupted track pauses before its spring: \(field)")
    }
}
for testSpeed in [0.1, 1, 2] {
    speed = testSpeed
    let collapsed = LuckTabBarFrame(expanded: false)
    precondition(collapsed.isRestingCompact && collapsed.labelOffset == -30, "First entrance must start at rest at -30")
    let first = timeline(true, from: collapsed)
    sample(first, expanded: true)
    // NOTE: Preserve the original entrance choreography, including its two resting holds.
    let originalEntrance = KeyframeTimeline(initialValue: collapsed) {
        KeyframeTrack(\.expansion) {
            LinearKeyframe(0, duration: 0.15 / speed)
            SpringKeyframe(1, spring: spring)
        }
        KeyframeTrack(\.nudge) {
            SpringKeyframe(40, duration: 0.1 / speed, spring: spring)
            SpringKeyframe(-10, duration: 0.05 / speed, spring: spring)
            SpringKeyframe(0, spring: spring)
        }
        KeyframeTrack(\.squeeze) {
            SpringKeyframe(40, duration: 0.15 / speed, spring: spring)
            SpringKeyframe(0, spring: spring)
        }
        KeyframeTrack(\.labelScale) {
            LinearKeyframe(0, duration: 0.05 / speed)
            SpringKeyframe(1, spring: spring)
        }
        KeyframeTrack(\.labelOffset) {
            LinearKeyframe(-30, duration: 0.05 / speed)
            SpringKeyframe(0, spring: Spring(response: 0.6 / speed, dampingRatio: 0.85))
        }
    }
    for time in Array(stride(from: 0.0, to: originalEntrance.duration, by: 1.0 / (120 * speed))) + [originalEntrance.duration] {
        for field: KeyPath<LuckTabBarFrame, CGFloat> in [\.expansion, \.nudge, \.squeeze, \.labelScale, \.labelOffset] {
            precondition(abs(first.value(time: time)[keyPath: field] - originalEntrance.value(time: time)[keyPath: field]) < 0.001,
                         "Resting entrance changed: \(field)")
        }
    }
    let collapse = timeline(false, from: first.value(time: first.duration))
    sample(collapse, expanded: false)
    let settled = collapse.value(time: collapse.duration)
    var compact = settled
    for _ in 0..<5 {
        precondition(compact.isRestingCompact && abs(compact.labelOffset + 10) < 0.001)
        let repeated = reverse(compact, wasExpanded: false)
        for time in Array(stride(from: 0.0, to: first.duration, by: 1.0 / (120 * speed))) + [first.duration] {
            for field in fields {
                precondition(abs(first.value(time: time)[keyPath: field] - repeated.value(time: time)[keyPath: field]) < 0.001,
                             "Repeated entrance differs from first entrance: \(field)")
            }
        }
        let nextCollapse = reverse(repeated.value(time: repeated.duration), wasExpanded: true)
        compact = nextCollapse.value(time: nextCollapse.duration)
        cycles += 1
    }
    // NOTE: Hidden labels restart even when another track has not settled.
    let writableFields: [WritableKeyPath<LuckTabBarFrame, CGFloat>] = [
        \.expansion, \.nudge, \.squeeze, \.buttonOffset, \.buttonScale,
        \.searchOffset, \.searchScale, \.visibility, \.labelScale, \.labelOffset, \.labelExponent
    ]
    for field in writableFields {
        var moving = settled
        moving[keyPath: field] += 0.01
        precondition(!moving.isRestingCompact, "Moving frame misclassified as resting: \(field)")
        _ = reverse(moving, wasExpanded: false)
    }
    let midCollapse = collapse.value(time: 0.15 / speed)
    precondition(midCollapse.visibility > 0.001 && !midCollapse.isRestingCompact)
    let reexpanded = reverse(midCollapse, wasExpanded: false)
    checkImmediateProgress(reexpanded, fields: [\.expansion, \.labelScale, \.labelOffset, \.buttonOffset])
    for visibility: CGFloat in [-0.02, 0, 0.001, 0.0011] {
        var moving = midCollapse
        moving.visibility = visibility
        moving.nudge = 4
        moving.squeeze = 4
        let interrupted = reverse(moving, wasExpanded: false)
        checkImmediateProgress(interrupted, fields: [\.expansion, \.nudge, \.squeeze, \.labelScale, \.labelOffset, \.buttonOffset])
        let early = interrupted.value(time: 0.01 / speed)
        precondition(early.nudge < moving.nudge && early.squeeze < moving.squeeze,
                     "Interrupted geometry replayed the resting nudge or squeeze")
    }
    for expanded in [true, false] {
        let animation = timeline(expanded, from: LuckTabBarFrame(expanded: !expanded))
        for interruption in [0.03, 0.08, 0.15, 0.25, 0.5] {
            let current = animation.value(time: interruption / speed)
            let reversed = reverse(current, wasExpanded: expanded)
            for secondInterruption in [0.03, 0.08, 0.15, 0.25, 0.5] {
                _ = reverse(reversed.value(time: secondInterruption / speed), wasExpanded: !expanded)
            }
        }
    }
    // NOTE: This offset previously jumped the fourth/fifth labels by 28.4/53.7 points.
    var visible = first.value(time: 0.15 / speed)
    visible.labelOffset = -4
    _ = reverse(visible, wasExpanded: true)
}
print("PASS: \(samples) finite timeline/render samples; \(reversals) interrupted reversals; \(hiddenResets) hidden label resets; \(cycles) repeat cycles; original entrance and immediate interruption progress; speeds 0.1/1/2; LTR/RTL; max visible reversal jump \(maxPositionJump) pt")
'''
spring = re.search(r'private var spring: Spring \{ ([^\n]+) \}', source).group(1)
subprocess.run(['xcrun', 'swift', '-'], input='import SwiftUI\nvar speed = 1.0\nvar spring: Spring { ' + spring + ' }\n' + frame + '\n' + tracks + rendering + checks, text=True, check=True)
