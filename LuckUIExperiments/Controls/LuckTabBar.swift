import SwiftUI

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

    @State private var initialFrame: LuckTabBarFrame
    @Namespace private var selectionNamespace
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.luckTabBarReduceMotion) private var requestedReduceMotion
    @Environment(\.luckTabBarAnimationSpeed) private var animationSpeed
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        // NOTE: Changing initialValue with the trigger resets the animator to its target.
        _initialFrame = State(initialValue: LuckTabBarFrame(expanded: isExpanded))
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
            KeyframeAnimator(initialValue: initialFrame,
                             trigger: isExpanded) { animated in
                let frame = reduceMotion ? LuckTabBarFrame(expanded: isExpanded) : animated
                strip(frame: frame, width: geometry.size.width)
            } keyframes: { value in
                tracks(from: value)
            }
        }
        .frame(height: isExpanded ? expandedHeight : compactHeight)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.83).speed(speed), value: isExpanded)
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
        HStack(spacing: 0) {
            ForEach(Array(visibleTabs.enumerated()), id: \.element.id) { index, tab in
                let order = CGFloat(index + 1)
                LuckTabViewStripButton(tab: tab, isSelected: tab.id == selection,
                                      namespace: selectionNamespace) { select(tab.id) }
                    .accessibilityHidden(!isExpanded)
                    .disabled(!isExpanded)
                    .scaleEffect(max(0.001, 1 - (1 - frame.labelScale) * sqrt(order)))
                    .offset(x: direction * frame.labelOffset * pow(order, frame.labelExponent))
                    .blur(radius: reduceMotion ? 0 : max(0, 1 - frame.labelScale) * 10)
            }
        }
        .padding(4)
        .frame(width: width, height: expandedHeight)
        .offset(x: direction * ((buttonSize + 8) * (1 - frame.expansion) + frame.nudge))
        .animation(reduceMotion || behavior == .compactAsDefault || searchFocused.wrappedValue ? nil :
            .spring(response: 0.38, dampingFraction: 0.8).speed(speed), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tabs")
    }

    private var spring: Spring { Spring(response: 0.6 / speed, dampingRatio: 0.8) }

    @KeyframesBuilder<LuckTabBarFrame>
    private func tracks(from value: LuckTabBarFrame) -> some Keyframes<LuckTabBarFrame> {
        KeyframeTrack(\.expansion) {
            if isExpanded && value.isRestingCompact {
                LinearKeyframe(value.expansion, duration: 0.15 / speed)
                SpringKeyframe(1, spring: spring)
            } else {
                SpringKeyframe(isExpanded ? 1 : 0, spring: spring)
            }
        }
        KeyframeTrack(\.nudge) {
            if isExpanded && value.isRestingCompact {
                SpringKeyframe(40, duration: 0.1 / speed, spring: spring)
                SpringKeyframe(-10, duration: 0.05 / speed, spring: spring)
                SpringKeyframe(0, spring: spring)
            } else {
                SpringKeyframe(0, spring: spring)
            }
        }
        KeyframeTrack(\.squeeze) {
            if isExpanded && value.isRestingCompact {
                SpringKeyframe(40, duration: 0.15 / speed, spring: spring)
                SpringKeyframe(0, spring: spring)
            } else {
                SpringKeyframe(0, spring: spring)
            }
        }
        KeyframeTrack(\.buttonOffset) { SpringKeyframe(isExpanded ? 150 : 0, spring: spring) }
        KeyframeTrack(\.buttonScale) { SpringKeyframe(isExpanded ? 0.5 : 1, spring: spring) }
        KeyframeTrack(\.searchOffset) { SpringKeyframe(isExpanded ? 30 : 0, spring: spring) }
        KeyframeTrack(\.searchScale) { SpringKeyframe(isExpanded ? 0.8 : 1, spring: spring) }
        KeyframeTrack(\.visibility) {
            SpringKeyframe(isExpanded ? 1 : 0, spring: Spring(response: 0.4 / speed, dampingRatio: 0.83))
        }
        KeyframeTrack(\.labelScale) {
            if isExpanded && value.isRestingCompact {
                LinearKeyframe(value.labelScale, duration: 0.05 / speed)
                SpringKeyframe(1, spring: spring)
            } else {
                SpringKeyframe(isExpanded ? 1 : 0, spring: spring)
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
                SpringKeyframe(isExpanded ? 0 : -10, spring: Spring(response: 0.6 / speed, dampingRatio: 0.85))
            }
        }
        KeyframeTrack(\.labelExponent) {
            SpringKeyframe(isExpanded ? 2.05 : 2.3, spring: spring)
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
