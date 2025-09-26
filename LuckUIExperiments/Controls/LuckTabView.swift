// LuckUIExperiments::LuckTabView.swift - 11/04/2025

import SwiftUI

protocol LuckNavigationDestination: CaseIterable, Identifiable, Hashable, Equatable, RawRepresentable
where AllCases == Array<Self>, RawValue: StringProtocol {
    var id: Self { get }
    
    associatedtype Content: View
    @ViewBuilder func view() -> Content
    
    var icon:     String { get }
    var isSearch: Bool   { get }
}

extension LuckNavigationDestination {
    var id: Self { self }
    var icon: String { get { return "gear" } }
    var isSearch: Bool { get { return false }}
}

extension EnvironmentValues {
    @Entry var luckSearchText: String = ""
    
    @Entry var luckTabViewAnimation: Animation = .default // TODO: remove?
    
    @Entry var luckIsSlowmo: Bool = false // TODO: this should be global, not LuckTabView-specific!
}

public enum LuckTabViewStripBehavior: String, CaseIterable, Identifiable, Equatable {
    public var id: Self { self }
    
    // 1. Idle state is expanded mode -> compact mode on search
    // This is canonical according to leaks / most comparable to current behavior.
    case CompactOnSearch
    // 2. Idle state is expanded mode -> compact mode on scroll and search
    case CompactOnScroll
    // 3. Idle state is compact mode - expanded mode only on command
    // As seen on X demo.
    case CompactAsDefault
    
    public static var `default`: Self { CompactAsDefault }
}

// MARK: - TODO:
// Adjust animation timings: collapse animation looks a little too fast, can barely see the merging
// Fun animations based on latest concept: https://www.youtube.com/watch?v=C5OQDhcqKjo

struct LuckTabView<Tab: LuckNavigationDestination>: View {
    @Namespace private var animNS
    
    // MARK: - Tab-related variables
    private let allTabs: Array<Tab>
    
    @State private var _internalSelection: Tab
           private var _externalSelection: Binding<Tab>? = nil
    
    private var _selectionBinding: Binding<Tab> { _externalSelection ?? $_internalSelection }
    
    var selection: Tab {
        get { _selectionBinding.wrappedValue }
        set { _selectionBinding.wrappedValue = newValue }
    }
    
    // MARK: - Other properties
    @State var tabStripBehavior: LuckTabViewStripBehavior
    
    @State private var isSlowmo = false
    
    init(tabType: Tab.Type, tabSelection: Binding<Tab>? = nil,
         tabStripBehavior: LuckTabViewStripBehavior = .default) {
        allTabs = tabType.allCases
        assert(allTabs.count > 0)
        
        __internalSelection = State(initialValue: allTabs.first!)
        _externalSelection = tabSelection
        
        self.tabStripBehavior = tabStripBehavior
        
        if tabStripBehavior == .CompactAsDefault { isTabStripExpanded = false }
    }
    
    @State private var isTabStripExpanded: Bool = false
    @State private var searchFieldText: String = ""
    
    @State private var safeAreaSize: CGSize = .zero
    
    @State private var contentScrollOffset: Double = 0
    
    func onContentScrollChanged(offset: Double) {
        if tabStripBehavior != .CompactOnScroll { return }
        if selection.isSearch { return }
        
        contentScrollOffset = offset
        isTabStripExpanded = offset <= 0
    }
    
    var body: some View {
        // MARK: - Tab content
        TabView(selection: _selectionBinding) {
            ForEach(allTabs) { tab in
                tab.view()
            }
            .onScrollGeometryChange(for: Double.self, of: { $0.contentOffset.y }, action: { old, new in
                onContentScrollChanged(offset: new)
            })
            // Ensure the content can scroll above the tab bar and its accessories:
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: safeAreaSize.height)
            }
            .toolbarVisibility(.hidden, for: .tabBar)
            .environment(\.luckSearchText, searchFieldText)
        }
        // MARK: - Tab strip legibility overlay
        .overlay(alignment: .bottom) { tabStripLegibilityOverlay }
        // MARK: - Tab strip content
        .safeAreaInset(edge: .bottom) {
            VStack {
                if showDebugBox { debugBox }
                
                LuckTabViewStrip(animNS: animNS,
                                 allTabs: allTabs, selectedTab: _selectionBinding,
                                 tabStripBehavior: $tabStripBehavior, isExpanded: $isTabStripExpanded,
                                 searchFieldText: $searchFieldText)
                .environment(\.luckIsSlowmo, isSlowmo)
            }
            .padding(24)
            // MARK: - Tab strip state animation
            .animation(.spring(response: 0.4, dampingFraction: 0.83).speed(isSlowmo ? 0.1 : 1), value: isTabStripExpanded)
            
            .onChange(of: tabStripBehavior) { oldValue, newValue in
                isTabStripExpanded = tabStripBehavior != .CompactAsDefault
            }
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { safeAreaSize = $0 })
        }
    }
    
    var tabStripLegibilityOverlay: some View {
        ZStack {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .opacity(0.3)
            
            VariableBlurView(maxBlurRadius: 4, direction: .blurredBottomClearTop, startOffset: 0)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        // NOTE: Because tabStrip and its siblings are in a safeAreaInset, the overlay
        // ends up automatically accounting for their size and drawing "behind them".
        // Because of that, this just adds padding:
        .frame(maxHeight: 32)
    }
    
    // TODO: cleanup
    @State private var showDebugBox = true
    var debugBox: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("LuckTabView Debug").font(.footnote).frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.primary).bold()
                    .opacity(0.76)
                
                Toggle(isOn: $showDebugBox, label: {})
            }
            
            HStack {
                Text("Tab Strip Behavior")
                Spacer()
                Picker("Tab Strip Behavior", selection: $tabStripBehavior) {
                    ForEach(LuckTabViewStripBehavior.allCases) { tab in Text(tab.rawValue) }
                }
            }
            if tabStripBehavior == .CompactOnScroll {
                Text("Scroll offset (y): \(contentScrollOffset)")
            }
            
            Toggle("Slow Animations (local)", isOn: $isSlowmo)
                .onChange(of: isSlowmo) { _, newValue in _ValueKeyframeAnimatorSlowMotion = newValue }
            
            Toggle("Tab Strip Expanded",      isOn: $isTabStripExpanded)
        }
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .padding()
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 12))
    }
}

fileprivate struct LuckTabViewStrip<Tab: LuckNavigationDestination>: View {
    var animNS: Namespace.ID
    
    @Environment(\.luckIsSlowmo) private var isSlowmo
    
    public var allTabs: Array<Tab>
    @Binding public var selectedTab: Tab
    
    @Binding public var tabStripBehavior: LuckTabViewStripBehavior
    
    @Binding public var isExpanded: Bool
    
    @Binding    public  var searchFieldText      : String
    @FocusState private var searchFieldFocusState: Bool
    
    @State private var tabSelectionAnimation: Animation = .spring(response: 0.38, dampingFraction: 0.8)
    @State private var tabStripExpandAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.83)
    
    var customTopInset: some View {
        HStack(spacing: 16) {
            Image(.AlbumArtwork.paradiseagain)
                .resizable().aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading) {
                Text("Calling On")
                // Text("Swedish House Mafia")
            }
            .font(.system(size: 15))
            
            Spacer()
            
            Group {
                Button(action: {}) {
                    Label("Play / resume", systemImage: "play.fill").labelStyle(.iconOnly)
                }
                Button(action: {}) {
                    Label("Next track", systemImage: "forward.fill").labelStyle(.iconOnly)
                }
            }
            .tint(.primary)
        }
        .padding(12)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .capsule)
    }
    
    // TODO: custom
    var tabStripTopContent: some View {
        #if true
        customTopInset
        #else
        VStack {
            Text("< accessory view >")
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(.thickMaterial))
        }
        #endif
    }
    
    @State private var compactViewGeo:  CGRect = .zero
    @State private var expandedViewGeo: CGRect = .zero
    
    private var tabStripContentHeight: CGFloat { !isExpanded ? compactViewGeo.height : expandedViewGeo.height }
    @State private var tabStripBottomOffset: CGFloat = 16 // TODO: revise
    
    var body: some View {
        VStack {
            tabStripTopContent
            
            Color.clear
                .frame(height: tabStripContentHeight - tabStripBottomOffset)
        }
        .overlay(alignment: .bottom) {
            tabStripView
                .offset(y: tabStripBottomOffset)
                .animation(tabStripExpandAnimation.speed(isSlowmo ? 0.1 : 1), value: isExpanded)
        }
    }
    
    var collapsedViewTabsIcon: String {
        if selectedTab.isSearch { return "chevron.backward" }
        return selectedTab.icon
    }
    
    let tabStripViewCoordinateSpace = "luckTabViewStripContent"
    var tabStripView: some View {
        ZStack(alignment: .top) { // TODO: no idea why this needs to be top, investigate!
            compactView
                .opacity(!isExpanded ? 1 : 0)
            
            tabStripMorphingPlatter
            
            expandedView
                .opacity(isExpanded ? 1 : 0)
        }
        .padding(.horizontal, 24) // HACK: to prevent clipping during the compact view collapse animation  @PreventClippingOnCollapse
        .morphContainer() {
            if !isExpanded { Rectangle().fill(.background) }
            else           { Rectangle().fill(.thinMaterial) }
        }
        .padding(.horizontal, -24) // @PreventClippingOnCollapse
        
        .coordinateSpace(name: tabStripViewCoordinateSpace)
    }
    
    struct TabStripPlatterMorphAnimationProps: Equatable {
        var position: CGPoint
        var size:     CGSize
        
        init(position: CGPoint, size: CGSize) {
            self.position = position
            self.size = size
        }
        init(rect: CGRect) { self.init(position: rect.origin, size: rect.size) }
        init() { self.init(rect: .zero) }
    }
    
    @State private var tabStripMorphingAnimProps = TabStripPlatterMorphAnimationProps()
    var tabStripMorphingPlatter: some View {
        ZStack {
            let compactViewAnimProps  = TabStripPlatterMorphAnimationProps(rect: compactViewSearchBarGeo)
            let expandedViewAnimProps = TabStripPlatterMorphAnimationProps(rect: expandedViewGeo)
            
            Spacer()
                .morphable(shape: .capsule, intensity: 5)
                .frame(width: tabStripMorphingAnimProps.size.width, height: tabStripMorphingAnimProps.size.height)
                .offset(x:    tabStripMorphingAnimProps.position.x, y: tabStripMorphingAnimProps.position.y)
            
                .valueKeyframeAnimator(properties: $tabStripMorphingAnimProps, trigger: isExpanded) { props in
                    KeyframeTrack(\.position) {
                        SpringKeyframe(isExpanded ? compactViewAnimProps.position.add(x: 40) : compactViewAnimProps.position, duration: 0.1, spring: tabExpansionSpring)
                        SpringKeyframe(isExpanded ? compactViewAnimProps.position.add(x: -10) : compactViewAnimProps.position, duration: 0.05, spring: tabExpansionSpring)
                        SpringKeyframe(isExpanded ? expandedViewAnimProps.position : compactViewAnimProps.position, spring: tabExpansionSpring)
                    }
                    KeyframeTrack(\.size) {
                        SpringKeyframe(isExpanded ? compactViewAnimProps.size.add(width: -40) : expandedViewAnimProps.size, duration: isExpanded ? 0.15 : 0, spring: tabExpansionSpring)
                        SpringKeyframe(isExpanded ? expandedViewAnimProps.size : compactViewAnimProps.size, spring: tabExpansionSpring)
                    }
                }
                .onAppear() {
                    tabStripMorphingAnimProps = .init(rect: compactViewSearchBarGeo)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    struct BasicKeyframeAnimProps: Equatable {
        var offset: CGPoint = .zero
        var scale:  CGPoint = .init(x: 1, y: 1)
    }
    
    let tabExpansionSpring = Spring(response: 0.6, dampingRatio: 0.8)
    
    @State var compactViewSearchBarGeo: CGRect = .zero
    @State var compactViewTabsButtonAnimProps = BasicKeyframeAnimProps()
    @State var compactViewSearchBarAnimProps  = BasicKeyframeAnimProps()
    var compactView: some View {
        HStack {
            // TODO: optical alignment: this button should probably be slightly smaller than the search field
            LuckTabViewStripCompactButton(animNS: animNS, icon: collapsedViewTabsIcon) {
                searchFieldFocusState = false
                isExpanded = true
            }
            .morphable(shape: .circle)
            .offset(x: compactViewTabsButtonAnimProps.offset.x)
            .scaleEffect(x: compactViewTabsButtonAnimProps.scale.x, y: compactViewTabsButtonAnimProps.scale.y)
            .blur(radius: isExpanded ? 10 : 0)
            .valueKeyframeAnimator(properties: $compactViewTabsButtonAnimProps, trigger: isExpanded) { props in
                KeyframeTrack(\.offset) {
                    let offset = isExpanded ? 150 : 0
                    SpringKeyframe(.init(x: offset, y: 0), spring: tabExpansionSpring)
                }
                KeyframeTrack(\.scale) {
                    let scale = isExpanded ? CGPoint(x: 0.5, y: 0.5) : CGPoint(x: 1, y: 1)
                    SpringKeyframe(scale, spring: tabExpansionSpring)
                }
            }
            
            // MARK: - Search field  @Behavior
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Artists, Songs, Lyrics and More", text: $searchFieldText) // TODO: placeholder parameter
                    .font(.system(size: 14))
                    .focused($searchFieldFocusState)
                    .onChange(of: searchFieldFocusState) { oldValue, newValue in
                        // TODO: kind of hacky:
                        selectedTab = allTabs.first(where: {$0.isSearch}) ?? selectedTab
                    }
            }
            .padding()
            .offset(x: compactViewSearchBarAnimProps.offset.x)
            .scaleEffect(x: compactViewSearchBarAnimProps.scale.x, y: compactViewSearchBarAnimProps.scale.y)
            .blur(radius: isExpanded ? 10 : 0)
            .valueKeyframeAnimator(properties: $compactViewSearchBarAnimProps, trigger: isExpanded) { props in
                KeyframeTrack(\.offset) {
                    let offset = isExpanded ? 30 : 0
                    SpringKeyframe(.init(x: offset, y: 0), spring: tabExpansionSpring)
                }
                KeyframeTrack(\.scale) {
                    let scale = isExpanded ? CGPoint(x: 0.8, y: 0.9) : CGPoint(x: 1, y: 1)
                    SpringKeyframe(scale, spring: tabExpansionSpring)
                }
            }
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named(tabStripViewCoordinateSpace)) }, action: { compactViewSearchBarGeo = $0 })
        }
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named(tabStripViewCoordinateSpace)) }, action: { compactViewGeo = $0 })
        .padding(.top)
    }
    
    @State var expandedViewTabButtonAnimProps = BasicKeyframeAnimProps()
    var expandedView: some View {
        HStack(spacing: 0) {
            let tabs = allTabs
            // Do not show the search tab when it isn't necessary (based on behavior mode):
            // Exception in CompactAsDefault mode to show it is When the search box is focused and we are on the search tab.
                .filter { tabStripBehavior != .CompactAsDefault || selectedTab.isSearch || !$0.isSearch }
            
            // TODO: animate indivudual tabs on isExpanded!
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                let fIndex = CGFloat(index)
                
                let scaleValue  = max(0, 1 - (1 - expandedViewTabButtonAnimProps.scale.x) * sqrt(fIndex+1))
                let offsetValue = expandedViewTabButtonAnimProps.offset.x * pow(fIndex+1, isExpanded ? 2.05 : 2.3)
                let blurValue   = (1 - expandedViewTabButtonAnimProps.scale.x) * 10
                
                LuckTabViewStripButton(
                    animNS: animNS,
                    isSelected: tab == selectedTab,
                    icon: tab.icon, title: tab.rawValue as! String,
                    action: { stripSelectTabAction(tab: tab) }
                )
                .scaleEffect(scaleValue)
                .offset(x: offsetValue)
                .blur(radius: blurValue)
                .onChange(of: selectedTab, onSelectedTabChanged)
                // @Behavior  smooth selection indicator position change when not collapsing:
                // FIXME: The SW keyboard causes some weird visuals as collapsedView sticks to the top
                .animation(tabStripBehavior != .CompactAsDefault && !searchFieldFocusState ? tabSelectionAnimation.speed(isSlowmo ? 0.1 : 1) : nil, value: selectedTab)
            }
        }
        .offset(x: tabStripMorphingAnimProps.position.x)
        .padding(4)
        .valueKeyframeAnimator(properties: $expandedViewTabButtonAnimProps, trigger: isExpanded, delay: isExpanded ? 0.05 : 0) { props in
            KeyframeTrack(\.scale) {
                let start = isExpanded ? 0 : 1
                let end   = isExpanded ? 1 : 0
                MoveKeyframe  (.init(x: start, y: start))
                SpringKeyframe(.init(x: end,   y: end), spring: tabExpansionSpring)
            }
            KeyframeTrack(\.offset) {
                let start = isExpanded ? -30 : 0
                let end   = isExpanded ? 0 : -10
                MoveKeyframe  (.init(x: start, y: start))
                SpringKeyframe(.init(x: end,   y: end), spring: Spring(response: 0.6, dampingRatio: 0.85))
            }
        }
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named(tabStripViewCoordinateSpace)) }, action: { expandedViewGeo = $0 })
    }
    
    func stripSelectTabAction(tab: Tab) {
        // For collapsing when tapping the same tab in CompactAsDefault behavior mode:
        if tabStripBehavior == .CompactAsDefault && selectedTab == tab {
            isExpanded = false
        }
        
        // NOTE: We don't collapse the tab strip on tab change here because of layout timing.
        // It is instead done in expandedView as part of an .onChange(of: selectedTab)
        
        searchFieldFocusState = tab.isSearch
        if tab.isSearch { isExpanded = false }
        
        selectedTab = tab
    }
    
    func onSelectedTabChanged() {
        // Collapse when in CompactAsDefault behavior mode on tab change:
        if tabStripBehavior == .CompactAsDefault { isExpanded = false }
        
        // Dismiss when selecting search tab, unfocus search field otherwise:
        if selectedTab.isSearch { isExpanded = false }
        else                    { searchFieldFocusState = false }
    }
    
    // TODO: move away!
    // MARK: - Light border
    let gradientStops: [Gradient.Stop] = {
        // Define how many stops you want. We'll use 4 to mimic the original.
        let count = 4
        // Generate random locations between 0 and 1, then sort them to ensure proper ordering.
        let locations = (0..<count).map { _ in CGFloat.random(in: 0...1) }.sorted()
        
        // Define opacity ranges for each stop to mimic light intensity variation.
        // You can adjust these ranges as needed.
        let opacities: [Double] = [
            Double.random(in: 0.15...0.2), // Dim light.
            Double.random(in: 0.2...0.25), // Slight glow.
            Double.random(in: 0.25...0.35),  // Moderate intensity.
            Double.random(in: 0.35...0.45), // Bright, intense light.
        ]
        
        // Pair the sorted locations with their corresponding opacities.
        return zip(locations, opacities).map { Gradient.Stop(color: Color.white.opacity($1), location: $0) }
    }()
    
    var lightBorder: some ShapeStyle {
        LinearGradient(
            stops: gradientStops,
            startPoint: .topTrailing,
            endPoint: .bottom
        )
        .blendMode(.overlay)
    }
}

#Preview {
    ContentView()
}
