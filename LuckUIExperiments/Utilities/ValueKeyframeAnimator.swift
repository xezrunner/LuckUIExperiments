// LuckUIExperiments::ValueKeyframeAnimator.swift - 18/08/2025

// An alternative to SwiftUI's KeyframeAnimator where changes are driven into a properties structure via Binding,
// without transforming the target view.

import SwiftUI

public struct ValueKeyframeAnimatorModifier<AnimationProperties, Path: Keyframes, Trigger: Equatable>: ViewModifier
where Path.Value == AnimationProperties {
    @State private var timeline: KeyframeTimeline<AnimationProperties>? = nil
    @State private var startDate: Date? = nil
    @State private var animating: Bool = false
    
    @State private var localProperties: AnimationProperties // This is effectively a 'local cache' for use per-frame
    
    @Binding var properties: AnimationProperties
    var trigger: Trigger
    
    let keyframesBuilder: (AnimationProperties) -> Path
    
    public init(properties: Binding<AnimationProperties>, trigger: Trigger, keyframes: @escaping (AnimationProperties) -> Path) {
        self._properties = properties
        self.trigger = trigger
        self.keyframesBuilder = keyframes
        _localProperties = State(initialValue: properties.wrappedValue) // set initial value on startup
        
        prepareTimeline(with: localProperties)
    }
    
    private func prepareTimeline(with value: AnimationProperties) {
        let path = keyframesBuilder(value)
        timeline = KeyframeTimeline(initialValue: value) { path }
    }
    
    public func body(content: Content) -> some View {
        content
            .overlay {
                TimelineView(.animation) { context in
                    EmptyView()
                        .onChange(of: context.date) { _, newValue in advanceFrame(date: newValue) }
                }
                .onChange(of: trigger, animate)
            }
    }
    
    private func animate() {
        prepareTimeline(with: localProperties)
        startDate = Date()
        animating = true
    }
    
    private func advanceFrame(date: Date) {
        if !animating { return }
        
        guard let startDate, let timeline else { return }
        
        let elapsed  = date.timeIntervalSince(startDate)
        let duration = timeline.duration
        let time     = min(max(0, elapsed), duration) // clamp
        
        let newProperties = timeline.value(time: time)
        
        if !isEqual(lhs: localProperties, rhs: newProperties) {
            localProperties = newProperties
            
            // Update external value without implicit animation:
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                properties = newProperties
            }
        }
        
        if elapsed > duration { animating = false }
    }
    
    // This is overriden in extensions depending on AnimationProperties.
    private func isEqual(lhs: AnimationProperties, rhs: AnimationProperties) -> Bool { false }
}

private extension ValueKeyframeAnimatorModifier where AnimationProperties: Equatable {
    func isEqual(lhs: AnimationProperties, rhs: AnimationProperties) -> Bool { lhs == rhs }
}
private extension ValueKeyframeAnimatorModifier where AnimationProperties: Hashable {
    func isEqual(lhs: AnimationProperties, rhs: AnimationProperties) -> Bool { lhs.hashValue == rhs.hashValue }
}

public extension View {
    // An alternative to SwiftUI's KeyframeAnimator that drives changes into an arbitrary value struct via a Binding,
    // without transforming the target view.
    /// - Parameters:
    ///   - value: Binding to the model to mutate.
    ///   - trigger: An Equatable value; changes rebuild the keyframes starting from the current value.
    ///   - keyframes: Builder producing a keyframe track hierarchy describing how properties evolve.
    func valueKeyframeAnimator<AnimationProperties, Path: Keyframes, Trigger: Equatable>(
        properties: Binding<AnimationProperties>, trigger: Trigger, keyframes: @escaping (AnimationProperties) -> Path) -> some View
    where Path.Value == AnimationProperties {
        modifier(ValueKeyframeAnimatorModifier(properties: properties, trigger: trigger, keyframes: keyframes))
    }
    
    /// Convenience overload using the bound value itself as the trigger (any change restarts animation).
    func valueKeyframeAnimator<AnimationProperties: Equatable, Path: Keyframes>(
        properties: Binding<AnimationProperties>, keyframes: @escaping (AnimationProperties) -> Path) -> some View
    where Path.Value == AnimationProperties {
        modifier(ValueKeyframeAnimatorModifier(properties: properties, trigger: properties.wrappedValue, keyframes: keyframes))
    }
}

#Preview {
    struct AnimProps {
        var offset: CGPoint = .init()
        var scale: CGPoint = .init(x: 1, y: 1)
    }
    
    struct DemoView: View {
        @State var props = AnimProps()
        @State var anim = false
        
        var body: some View {
            VStack {
                
                Text("I'm being animated!")
                    .buttonStyle(.borderedProminent)
                    .offset(x: props.offset.x)
                    .valueKeyframeAnimator(properties: $props, trigger: anim) { props in
                        KeyframeTrack(\.offset) {
                            SpringKeyframe(.init(x: -20, y: 0), duration: 0.15, spring: .bouncy)
                            SpringKeyframe(.init(x: 50, y: 0), spring: .bouncy)
                        }
                    }
                    .padding()
                
                Button("Trigger animation") { anim.toggle() }
            }
        }
    }
    
    return DemoView()
}

