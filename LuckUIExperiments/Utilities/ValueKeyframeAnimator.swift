// LuckUIExperiments::ValueKeyframeAnimator.swift - 18/08/2025

// An alternative to SwiftUI's KeyframeAnimator where changes are driven into a properties structure via Binding,
// without transforming the target view.

import SwiftUI

var _ValueKeyframeAnimatorSlowMotion:     Bool   = false
var _ValueKeyframeAnimatorSlowMotionness: Double = 10.0
#if canImport(UIKit)
// The Simulator changes this value for Debug > Slow Animations:
@_silgen_name("UIAnimationDragCoefficient") func UIAnimationDragCoefficient() -> Float
// Use UIKit animation speed when not requesting slow motion in this control:
var animationSpeedMultiplier: Double { !_ValueKeyframeAnimatorSlowMotion ? Double(UIAnimationDragCoefficient()) : _ValueKeyframeAnimatorSlowMotionness }
#else
var animationSpeedMultiplier: Double { !_ValueKeyframeAnimatorSlowMotion ? 1.0 : _ValueKeyframeAnimatorSlowMotionMult }
#endif

public struct ValueKeyframeAnimatorModifier<AnimationProperties: Equatable, Path: Keyframes, Trigger: Equatable>: ViewModifier
where Path.Value == AnimationProperties {
    @State private var localProperties: AnimationProperties // This is effectively a 'local cache' for use per-frame
    
    @Binding var properties: AnimationProperties
    var trigger: Trigger
    
    let keyframesBuilder: (AnimationProperties) -> Path
    
    public init(properties: Binding<AnimationProperties>, trigger: Trigger, @KeyframesBuilder<AnimationProperties> keyframes: @escaping (AnimationProperties) -> Path) {
        self._properties = properties
        self.trigger = trigger
        self.keyframesBuilder = keyframes
        _localProperties = State(initialValue: properties.wrappedValue) // set initial value on startup
        // Defer actual timeline build until first animate() call so that timeline duration
        // can reflect newest keyframe definition tied to trigger.
    }
    
    @State private var timeline: KeyframeTimeline<AnimationProperties>? = nil
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
                .onChange(of: properties) { _, newValue in
                    // Update the initial local properties if they change outside prior to animating,
                    // so that we react to property changes for the view before animating:
                    // FIXME: protocol for AnimationProperties?
                    if !animating { localProperties = newValue }
                }
            }
    }
    
    @State private var animLastFrame: Date?
    @State private var animTime:      TimeInterval = 0
    
    @State private var animating: Bool = false
    
    private func animate() {
        prepareTimeline(with: localProperties)
        animLastFrame = Date()
        animTime = 0
        animating = true
    }
    
    private func advanceFrame(date: Date) {
        if !animating { return }
        
        guard let timeline, let animLastFrame else { return }
        
        // Accumulate time since last frame, divided by the animation slowness:
        // TODO: verify that we are actually animating at the correct speed in practice:
        let delta = date.timeIntervalSince(animLastFrame)
        if delta >= 0 { animTime += delta / animationSpeedMultiplier }
        self.animLastFrame = date
        
        let duration = timeline.duration
        let time     = min(animTime, duration)
        
        let newProperties = timeline.value(time: time)
        
        if localProperties != newProperties {
            localProperties = newProperties
            
            // Update external value without implicit animation:
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                properties = newProperties
            }
        }
        
        if animTime > duration { animating = false }
    }
}


public extension View {
    // An alternative to SwiftUI's KeyframeAnimator that drives changes into an arbitrary value struct via a Binding,
    // without transforming the target view.
    /// - Parameters:
    ///   - properties: Binding to the model to mutate.
    ///   - trigger: An Equatable value; changes rebuild the keyframes starting from the current value.
    ///   - keyframes: Builder producing a keyframe track hierarchy describing how properties evolve.
    func valueKeyframeAnimator<AnimationProperties: Equatable, Path: Keyframes, Trigger: Equatable>(
        properties: Binding<AnimationProperties>, trigger: Trigger, @KeyframesBuilder<AnimationProperties> keyframes: @escaping (AnimationProperties) -> Path) -> some View
    where Path.Value == AnimationProperties {
        modifier(ValueKeyframeAnimatorModifier(properties: properties, trigger: trigger, keyframes: keyframes))
    }
    
    /// Convenience overload using the bound value itself as the trigger (any change restarts animation).
    func valueKeyframeAnimator<AnimationProperties: Equatable, Path: Keyframes>(
        properties: Binding<AnimationProperties>, @KeyframesBuilder<AnimationProperties> keyframes: @escaping (AnimationProperties) -> Path) -> some View
    where Path.Value == AnimationProperties {
        modifier(ValueKeyframeAnimatorModifier(properties: properties, trigger: properties.wrappedValue, keyframes: keyframes))
    }
}

#Preview {
    struct AnimProps: Equatable {
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
                    .scaleEffect(props.scale.x)
                    .valueKeyframeAnimator(properties: $props, trigger: anim) { props in
                        KeyframeTrack(\.offset) {
                            SpringKeyframe(.init(x: -20, y: 0), duration: 0.15, spring: .bouncy)
                            SpringKeyframe(.init(x: 50, y: 0), spring: .bouncy)
                        }
                        KeyframeTrack(\.scale) {
                            SpringKeyframe(.init(x: 1, y: 0), duration: 0.15, spring: .bouncy)
                            SpringKeyframe(.init(x: 1.5, y: 0), spring: .bouncy)
                        }
                    }
                    .padding()
                
                Button("Trigger animation") { anim.toggle() }
            }
        }
    }
    
    return DemoView()
}

