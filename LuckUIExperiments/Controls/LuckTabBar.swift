import SwiftUI
import QuartzCore

struct LuckTabBar<Selection: Hashable>: View {
    let tabs: [LuckTab<Selection>]
    let selection: Selection
    let behavior: LuckTabViewStripBehavior
    let isExpanded: Bool
    let expandedHeight: CGFloat
    let compactHeight: CGFloat
    @Binding var searchText: String
    let searchPrompt: LocalizedStringKey
    let searchFocused: FocusState<Bool>.Binding
    let select: (Selection) -> Void
    let expand: () -> Void

    @State private var motion: LuckTabBarMotion
    @State private var dragLocation: CGPoint?
    @State private var dragOriginFrame: CGRect = .zero
    @State private var tabRowFrame: CGRect = .zero
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.luckTabBarReduceMotion) private var requestedReduceMotion
    @Environment(\.luckTabBarAnimationSpeed) private var animationSpeed
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .caption) private var scaledTabWidth: CGFloat = 80

    init(tabs: [LuckTab<Selection>], selection: Selection, behavior: LuckTabViewStripBehavior,
         isExpanded: Bool, expandedHeight: CGFloat, compactHeight: CGFloat,
         searchText: Binding<String>, searchPrompt: LocalizedStringKey,
         searchFocused: FocusState<Bool>.Binding, select: @escaping (Selection) -> Void,
         expand: @escaping () -> Void) {
        self.tabs = tabs
        self.selection = selection
        self.behavior = behavior
        self.isExpanded = isExpanded
        self.expandedHeight = expandedHeight
        self.compactHeight = compactHeight
        _searchText = searchText
        self.searchPrompt = searchPrompt
        self.searchFocused = searchFocused
        self.select = select
        self.expand = expand
        _motion = State(initialValue: LuckTabBarMotion(expanded: isExpanded))
    }

    private var buttonSize: CGFloat { compactHeight - 4 }
    private var speed: Double { max(0.1, animationSpeed) }
    private var direction: CGFloat { layoutDirection == .rightToLeft ? -1 : 1 }
    private var reduceMotion: Bool { systemReduceMotion || requestedReduceMotion }
    private var selectedTab: LuckTab<Selection> { tabs.first { $0.id == selection } ?? tabs[0] }
    private var hasSearch: Bool { tabs.contains { $0.role == .search } }
    private var visibleTabs: [LuckTab<Selection>] {
        tabs.filter { behavior != .compactAsDefault || selectedTab.role == .search || $0.role != .search }
    }

    var body: some View {
        GeometryReader { geometry in
            strip(frame: motion.frame, width: geometry.size.width)
                // NOTE: The recognizer must outlive the compact button as expansion removes it.
                .gesture(LuckTabDragGesture(
                    canBegin: { point in canBeginDrag(at: point, bounds: geometry.frame(in: .global)) },
                    changed: { point, began in
                        guard began || dragLocation != nil else { return }
                        withTransaction(Transaction(animation: nil)) {
                            if began { dragOriginFrame = geometry.frame(in: .global) }
                            dragLocation = point
                        }
                        if !isExpanded { expand() }
                    },
                    ended: { point in endDrag(at: point) }))
                .onChange(of: geometry.size.width) { _, _ in cancelDrag() }
        }
        .onChange(of: selection) { _, _ in cancelDrag() }
        .onChange(of: visibleTabs.map(\.id)) { _, _ in cancelDrag() }
        .onChange(of: behavior) { _, _ in cancelDrag() }
        .onChange(of: layoutDirection) { _, _ in cancelDrag() }
        .onChange(of: dynamicTypeSize) { _, _ in cancelDrag() }
        .onChange(of: isExpanded) { _, expanded in
            if !expanded { cancelDrag() }
            animate()
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { motion.settle(at: LuckTabBarFrame(expanded: isExpanded)) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                cancelDrag()
                motion.finish()
            }
        }
        .onAppear { motion.settle(at: LuckTabBarFrame(expanded: isExpanded)) }
        .onDisappear {
            cancelDrag()
            motion.finish()
        }
        .frame(height: isExpanded ? expandedHeight : compactHeight)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.83).speed(speed), value: isExpanded)
    }

    private func animate() {
        let target = LuckTabBarFrame(expanded: isExpanded)
        guard !reduceMotion, scenePhase == .active else {
            motion.settle(at: target)
            return
        }
        let timeline = KeyframeTimeline(initialValue: motion.frame) {
            tracks(from: motion.frame)
        }
        motion.play(timeline, target: target)
    }

    private func strip(frame: LuckTabBarFrame, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            platter(frame: frame, width: width)
            if !isExpanded || frame.visibility < 0.999 {
                compact(frame: frame, width: width)
                    .opacity(1 - frame.visibility)
                    .allowsHitTesting(!isExpanded)
                    .disabled(isExpanded)
                    .accessibilityHidden(isExpanded)
            }
            if isExpanded || frame.visibility > 0.001 {
                expanded(frame: frame, width: width)
                    .opacity(frame.visibility)
                    .allowsHitTesting(isExpanded)
                    .disabled(!isExpanded)
                    .accessibilityHidden(!isExpanded)
            }
        }
        .frame(width: width, alignment: .topLeading)
    }

    private func platter(frame: LuckTabBarFrame, width: CGFloat) -> some View {
        let inset = buttonSize + 8
        let x = inset * (1 - frame.expansion) + frame.nudge
        let size = CGSize(width: max(1, width - inset + inset * frame.expansion - frame.squeeze),
                          height: compactHeight + (expandedHeight - compactHeight) * frame.expansion)
        let circleSize = buttonSize * frame.buttonScale
        let circleX = frame.buttonOffset * frame.buttonScale + (buttonSize - circleSize) / 2
        let entities = [
            SDFMorphableEntity(shapeType: .circle,
                position: CGPoint(x: 24 + physicalX(circleX, width: circleSize, container: width),
                                  y: 24 + (compactHeight - circleSize) / 2),
                size: CGSize(width: circleSize, height: circleSize), intensity: 15),
            SDFMorphableEntity(shapeType: .capsule,
                position: CGPoint(x: 24 + physicalX(x, width: size.width, container: width), y: 24),
                size: size, intensity: 5)
        ]
        return ZStack {
            Rectangle().fill(.background)
                .opacity(reduceTransparency ? 1 : 1 - frame.visibility)
            if !reduceTransparency {
                Rectangle().fill(.thinMaterial).opacity(frame.visibility)
            }
        }
        .frame(width: width + 48, height: max(compactHeight, expandedHeight) + 48)
        .mask { SDFMorphMask(entities: entities) }
        .compositingGroup()
        .shadow(color: .black.opacity(0.08), radius: 4)
        .offset(x: -24 * direction, y: -24)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func physicalX(_ x: CGFloat, width: CGFloat, container: CGFloat) -> CGFloat {
        layoutDirection == .rightToLeft ? container - x - width : x
    }

    private func compact(frame: LuckTabBarFrame, width: CGFloat) -> some View {
        HStack(spacing: 8) {
            Button(action: expand) {
                Image(systemName: selectedTab.role == .search ? "chevron.backward" : selectedTab.systemImage)
                    .font(.system(size: 20))
                    .frame(width: buttonSize, height: buttonSize)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(isExpanded)
            .disabled(isExpanded)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Show tabs")
            .accessibilityIdentifier("luck.tabs.expand")
            .offset(x: direction * frame.buttonOffset)
            .scaleEffect(frame.buttonScale)
            .blur(radius: reduceMotion ? 0 : 10 * frame.visibility)

            Group {
                if hasSearch {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(searchPrompt, text: $searchText)
                            .font(.subheadline)
                            .focused(searchFocused)
                            .submitLabel(.search)
                            .onSubmit { searchFocused.wrappedValue = false }
                            .accessibilityIdentifier("luck.search")
                            .accessibilityHidden(isExpanded)
                            .disabled(isExpanded)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, searchText.isEmpty ? 16 : 4)
                } else {
                    Button(action: expand) {
                        HStack {
                            Text(selectedTab.title)
                            Spacer()
                            Image(systemName: "chevron.up")
                        }
                        .padding(.horizontal, 16)
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Show all tabs")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: compactHeight)
            .offset(x: direction * frame.searchOffset)
            .scaleEffect(x: frame.searchScale, y: 1 - 0.1 * frame.visibility)
            .blur(radius: reduceMotion ? 0 : 10 * frame.visibility)
        }
        .frame(width: width, height: compactHeight)
    }

    @ViewBuilder private func expanded(frame: LuckTabBarFrame, width: CGFloat) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    tabButtons(frame: frame, width: max(width, CGFloat(visibleTabs.count) * max(110, scaledTabWidth)))
                }
                .scrollIndicators(.hidden)
                .onChange(of: selection, initial: true) { _, id in
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .frame(width: width, height: expandedHeight)
        } else {
            tabButtons(frame: frame, width: width)
        }
    }

    private func tabButtons(frame: LuckTabBarFrame, width: CGFloat) -> some View {
        let cellWidth = (width - 8) / CGFloat(visibleTabs.count)
        let selectedIndex = CGFloat(visibleTabs.firstIndex { $0.id == selection } ?? 0)
        let position = dragLocation.map { dragPosition(at: $0) } ?? selectedIndex
        let preview = Int(position.rounded())
        return HStack(spacing: 0) {
            ForEach(Array(visibleTabs.enumerated()), id: \.element.id) { index, tab in
                let order = CGFloat(index + 1)
                LuckTabViewStripButton(tab: tab, isSelected: tab.id == selection,
                                      isHighlighted: index == preview) { select(tab.id) }
                    .accessibilityHidden(!isExpanded)
                    .disabled(!isExpanded)
                    .scaleEffect(max(0.001, 1 - (1 - frame.labelScale) * sqrt(order)))
                    .offset(x: direction * frame.labelOffset * pow(order, frame.labelExponent))
                    .blur(radius: reduceMotion ? 0 : max(0, 1 - frame.labelScale) * 10)
            }
        }
        .padding(4)
        .frame(width: width, height: expandedHeight)
        .background(alignment: .topLeading) {
            Capsule().fill(.background)
                .frame(width: cellWidth, height: expandedHeight - 8)
                .shadow(color: .black.opacity(0.1), radius: 4)
                .scaleEffect(max(0.001, 1 - (1 - frame.labelScale) * sqrt(position + 1)))
                .offset(x: direction * frame.labelOffset * pow(position + 1, frame.labelExponent))
                .blur(radius: reduceMotion ? 0 : max(0, 1 - frame.labelScale) * 10)
                .offset(x: direction * (4 + position * cellWidth), y: 4)
                .animation(dragLocation == nil ? selectionAnimation : nil, value: dragLocation == nil)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .offset(x: direction * ((buttonSize + 8) * (1 - frame.expansion) + frame.nudge))
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { tabRowFrame = $0 }
        .animation(reduceMotion || behavior == .compactAsDefault || searchFocused.wrappedValue ? nil :
            .spring(response: 0.38, dampingFraction: 0.8).speed(speed), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tabs")
    }

    private func dragPosition(at point: CGPoint) -> CGFloat {
        let cellWidth = max(1, (tabRowFrame.width - 8) / CGFloat(visibleTabs.count))
        let x = layoutDirection == .rightToLeft ? tabRowFrame.maxX - point.x : point.x - tabRowFrame.minX
        return min(CGFloat(visibleTabs.count - 1), max(0, (x - 4) / cellWidth - 0.5))
    }

    private func canBeginDrag(at point: CGPoint, bounds: CGRect) -> Bool {
        guard scenePhase == .active, bounds.contains(point) else { return false }
        if !isExpanded {
            let size = buttonSize * motion.frame.buttonScale
            let x = motion.frame.buttonOffset * motion.frame.buttonScale + (buttonSize - size) / 2
            let circle = CGRect(x: bounds.minX + physicalX(x, width: size, container: bounds.width),
                                y: bounds.minY + (compactHeight - size) / 2, width: size, height: size)
            return circle.contains(point)
        }
        // NOTE: At accessibility sizes, unselected tabs remain a scroll surface.
        return !dynamicTypeSize.isAccessibilitySize ||
            visibleTabs[Int(dragPosition(at: point).rounded())].id == selection
    }

    private var selectionAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.8).speed(speed)
    }

    private func endDrag(at point: CGPoint?) {
        guard dragLocation != nil else { return }
        // NOTE: Dismissing the search keyboard moves the strip away from the original finger height.
        let releaseBounds = tabRowFrame.union(dragOriginFrame).insetBy(dx: -32, dy: -44)
        guard let point, releaseBounds.contains(point) else {
            cancelDrag()
            return
        }
        let id = visibleTabs[Int(dragPosition(at: point).rounded())].id
        withAnimation(selectionAnimation) { dragLocation = nil }
        select(id)
    }

    private func cancelDrag() {
        withAnimation(selectionAnimation) { dragLocation = nil }
    }

    private var spring: Spring { Spring(response: 0.6 / speed, dampingRatio: 0.8) }

    @KeyframesBuilder<LuckTabBarFrame>
    private func tracks(from value: LuckTabBarFrame) -> some Keyframes<LuckTabBarFrame> {
        KeyframeTrack(\.expansion) {
            if isExpanded && value.isRestingCompact {
                LinearKeyframe(value.expansion, duration: 0.15 / speed)
                SpringKeyframe(1, spring: spring)
            } else {
                SpringKeyframe(isExpanded ? 1 : 0, spring: spring, startVelocity: motion.velocity(\.expansion))
            }
        }
        KeyframeTrack(\.nudge) {
            if isExpanded && value.isRestingCompact {
                SpringKeyframe(40, duration: 0.1 / speed, spring: spring)
                SpringKeyframe(-10, duration: 0.05 / speed, spring: spring)
                SpringKeyframe(0, spring: spring)
            } else {
                SpringKeyframe(0, spring: spring, startVelocity: motion.velocity(\.nudge))
            }
        }
        KeyframeTrack(\.squeeze) {
            if isExpanded && value.isRestingCompact {
                SpringKeyframe(40, duration: 0.15 / speed, spring: spring)
                SpringKeyframe(0, spring: spring)
            } else {
                SpringKeyframe(0, spring: spring, startVelocity: motion.velocity(\.squeeze))
            }
        }
        KeyframeTrack(\.buttonOffset) {
            SpringKeyframe(isExpanded ? 150 : 0, spring: spring, startVelocity: motion.velocity(\.buttonOffset))
        }
        KeyframeTrack(\.buttonScale) {
            SpringKeyframe(isExpanded ? 0.5 : 1, spring: spring, startVelocity: motion.velocity(\.buttonScale))
        }
        KeyframeTrack(\.searchOffset) {
            SpringKeyframe(isExpanded ? 30 : 0, spring: spring, startVelocity: motion.velocity(\.searchOffset))
        }
        KeyframeTrack(\.searchScale) {
            SpringKeyframe(isExpanded ? 0.8 : 1, spring: spring, startVelocity: motion.velocity(\.searchScale))
        }
        KeyframeTrack(\.visibility) {
            SpringKeyframe(isExpanded ? 1 : 0, spring: Spring(response: 0.4 / speed, dampingRatio: 0.83),
                           startVelocity: motion.velocity(\.visibility))
        }
        KeyframeTrack(\.labelScale) {
            if isExpanded && value.isRestingCompact {
                LinearKeyframe(value.labelScale, duration: 0.05 / speed)
                SpringKeyframe(1, spring: spring)
            } else {
                SpringKeyframe(isExpanded ? 1 : 0, spring: spring, startVelocity: motion.velocity(\.labelScale))
            }
        }
        KeyframeTrack(\.labelOffset) {
            if isExpanded && value.visibility <= 0.001 {
                // NOTE: Hidden labels can restart their entrance while the geometry keeps moving.
                if value.isRestingCompact {
                    MoveKeyframe(-30)
                    LinearKeyframe(-30, duration: 0.05 / speed)
                    SpringKeyframe(0, spring: Spring(response: 0.6 / speed, dampingRatio: 0.85))
                } else {
                    MoveKeyframe(-30)
                    SpringKeyframe(0, spring: Spring(response: 0.6 / speed, dampingRatio: 0.85))
                }
            } else {
                SpringKeyframe(isExpanded ? 0 : -10, spring: Spring(response: 0.6 / speed, dampingRatio: 0.85),
                               startVelocity: motion.velocity(\.labelOffset))
            }
        }
        KeyframeTrack(\.labelExponent) {
            SpringKeyframe(isExpanded ? 2.05 : 2.3, spring: spring, startVelocity: motion.velocity(\.labelExponent))
        }
    }
}

private struct LuckTabDragGesture: UIGestureRecognizerRepresentable {
    var canBegin: (CGPoint) -> Bool
    var changed: (CGPoint, Bool) -> Void
    var ended: (CGPoint?) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(converter: converter, canBegin: canBegin)
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.canBegin = canBegin
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed: changed(context.converter.location(in: .global), recognizer.state == .began)
        case .ended: ended(context.converter.location(in: .global))
        case .cancelled, .failed: ended(nil)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let converter: CoordinateSpaceConverter
        var canBegin: (CGPoint) -> Bool
        private var startLocation: CGPoint = .zero

        init(converter: CoordinateSpaceConverter, canBegin: @escaping (CGPoint) -> Bool) {
            self.converter = converter
            self.canBegin = canBegin
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // NOTE: Pan translation can still be zero at recognition on iOS 18.
            let velocity = converter.velocity(in: .global) ?? .zero
            return abs(velocity.x) > abs(velocity.y) && canBegin(startLocation)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            startLocation = converter.convert(globalPoint: touch.location(in: nil), to: .global)
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // NOTE: The selected cell scrubs; rejected origins let the accessibility row scroll.
            guard let scrollView = otherGestureRecognizer.view as? UIScrollView else { return false }
            return otherGestureRecognizer === scrollView.panGestureRecognizer
        }
    }
}

private struct LuckTabBarFrame {
    var expansion: CGFloat
    var nudge: CGFloat = 0
    var squeeze: CGFloat = 0
    var buttonOffset: CGFloat
    var buttonScale: CGFloat
    var searchOffset: CGFloat
    var searchScale: CGFloat
    var visibility: CGFloat
    var labelScale: CGFloat
    var labelOffset: CGFloat
    var labelExponent: CGFloat

    var isRestingCompact: Bool {
        // NOTE: Springs finish near their targets; 0.001 also matches the hidden-label cutoff.
        abs(expansion) < 0.001 && abs(nudge) < 0.001 && abs(squeeze) < 0.001 &&
        abs(buttonOffset) < 0.001 && abs(buttonScale - 1) < 0.001 &&
        abs(searchOffset) < 0.001 && abs(searchScale - 1) < 0.001 &&
        abs(visibility) < 0.001 && abs(labelScale) < 0.001 &&
        (abs(labelOffset + 30) < 0.001 || abs(labelOffset + 10) < 0.001) &&
        abs(labelExponent - 2.3) < 0.001
    }

    init(expanded: Bool) {
        expansion = expanded ? 1 : 0
        buttonOffset = expanded ? 150 : 0
        buttonScale = expanded ? 0.5 : 1
        searchOffset = expanded ? 30 : 0
        searchScale = expanded ? 0.8 : 1
        visibility = expanded ? 1 : 0
        labelScale = expanded ? 1 : 0
        labelOffset = expanded ? 0 : -30
        labelExponent = expanded ? 2.05 : 2.3
    }
}

// NOTE: Keep the last presented frame ourselves. KeyframeAnimator can restart from its
// initial value after idle, skipping a collapse even though the bar is visibly expanded.
@MainActor @Observable
private final class LuckTabBarMotion: NSObject {
    private(set) var frame: LuckTabBarFrame
    @ObservationIgnored private var timeline: KeyframeTimeline<LuckTabBarFrame>?
    @ObservationIgnored private var target: LuckTabBarFrame
    @ObservationIgnored private var startedAt: CFTimeInterval = 0
    @ObservationIgnored private var sampleTime: TimeInterval = 0
    @ObservationIgnored private var displayLink: CADisplayLink?

    init(expanded: Bool) {
        let initial = LuckTabBarFrame(expanded: expanded)
        frame = initial
        target = initial
    }

    func play(_ timeline: KeyframeTimeline<LuckTabBarFrame>, target: LuckTabBarFrame) {
        self.timeline = timeline
        self.target = target
        startedAt = CACurrentMediaTime()
        sampleTime = 0
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        // NOTE: ProMotion is a preference; power and thermal policy can select a lower rate.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard let timeline else { return }
        let elapsed = max(0, link.targetTimestamp - startedAt)
        guard elapsed < timeline.duration else {
            finish()
            return
        }
        sampleTime = elapsed
        withTransaction(Transaction(animation: nil)) {
            frame = timeline.value(time: elapsed)
        }
    }

    func velocity(_ keyPath: KeyPath<LuckTabBarFrame, CGFloat>) -> CGFloat {
        guard let timeline else { return 0 }
        // NOTE: Retarget with the velocity at the presented frame, keeping interrupted springs connected.
        let before = max(0, sampleTime - 0.0001)
        let after = min(timeline.duration, sampleTime + 0.0001)
        guard after > before else { return 0 }
        return (timeline.value(time: after)[keyPath: keyPath] -
                timeline.value(time: before)[keyPath: keyPath]) / (after - before)
    }

    func settle(at target: LuckTabBarFrame) {
        self.target = target
        finish()
    }

    func finish() {
        displayLink?.invalidate()
        displayLink = nil
        timeline = nil
        withTransaction(Transaction(animation: nil)) { frame = target }
    }
}
