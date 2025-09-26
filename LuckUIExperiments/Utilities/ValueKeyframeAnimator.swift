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
    @Binding var properties: AnimationProperties
    var trigger: Trigger
    @State var delay: Double = 0
    @KeyframesBuilder<AnimationProperties> var keyframesBuilder: (AnimationProperties) -> Path
    
    @State private var localProperties: AnimationProperties // This is effectively a 'local cache' for use per-frame
    
    public init(properties: Binding<AnimationProperties>, trigger: Trigger, delay: Double, @KeyframesBuilder<AnimationProperties> keyframes: @escaping (AnimationProperties) -> Path) {
        self._properties = properties
        self.trigger = trigger
        self.delay = delay
        self.keyframesBuilder = keyframes
        
        _localProperties = State(initialValue: properties.wrappedValue)
        
        animTransaction = Transaction()
        animTransaction.disablesAnimations = true // TODO: this is meant to disable implicit animations - verify whether it's actually needed.
    }
    
    @State private var timeline: KeyframeTimeline<AnimationProperties>? = nil
    private func prepareTimeline(with value: AnimationProperties) {
        let path = keyframesBuilder(value)
        timeline = KeyframeTimeline(initialValue: value) { path }
    }
    
    var animTransaction: Transaction
    
    public func body(content: Content) -> some View {
        content
            .overlay {
                if animating {
                    TimelineView(.animation) { context in
                        EmptyView()
                            .onChange(of: context.date) { _, newValue in advanceFrame(date: newValue) }
                    }
                }
            }
//            .overlay { Text("animTime: \(animTime)").background(animating ? .green : .gray) }
            .onChange(of: trigger, animate)
            .onChange(of: properties) { _, newValue in
                // Update the initial local properties if they change outside prior to animating,
                // so that we react to property changes for the view before animating:
                // FIXME: protocol for AnimationProperties?
                if !animating { localProperties = newValue }
            }
    }
    
    @State private var animLastFrame: Date?
    @State private var animTime:      TimeInterval = 0
    
    @State private var animating: Bool = false
    
    private func animate() {
        prepareTimeline(with: localProperties)
        animLastFrame = Date()
        animTime = 0 - delay
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
        let time     = min(max(0, animTime), duration)
        
        let newProperties = timeline.value(time: time)
        
        if newProperties != localProperties {
            localProperties = newProperties
            
            withTransaction(animTransaction) {
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
        properties: Binding<AnimationProperties>, trigger: Trigger, delay: Double = 0, @KeyframesBuilder<AnimationProperties> keyframes: @escaping (AnimationProperties) -> Path) -> some View
    where Path.Value == AnimationProperties {
        modifier(ValueKeyframeAnimatorModifier(properties: properties, trigger: trigger, delay: delay, keyframes: keyframes))
    }
    
    /// Convenience overload using the bound value itself as the trigger (any change restarts animation).
    func valueKeyframeAnimator<AnimationProperties: Equatable, Path: Keyframes>(
        properties: Binding<AnimationProperties>, delay: Double = 0, @KeyframesBuilder<AnimationProperties> keyframes: @escaping (AnimationProperties) -> Path) -> some View
    where Path.Value == AnimationProperties {
        modifier(ValueKeyframeAnimatorModifier(properties: properties, trigger: properties.wrappedValue, delay: delay, keyframes: keyframes))
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

