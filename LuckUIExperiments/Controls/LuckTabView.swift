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
    
    public static var `default`: Self { CompactOnSearch }
}

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
    
    @State private var isTabStripExpanded: Bool = true
    @State private var searchFieldText: String = ""
    
    var body: some View {
        // MARK: - Tab content
        TabView(selection: _selectionBinding) {
            ForEach(allTabs) { tab in
                tab.view()
            }
            .toolbarVisibility(.hidden, for: .tabBar)
            .environment(\.luckSearchText, searchFieldText)
        }
        // MARK: - Tab strip legibility overlay
        .overlay(alignment: .bottom) { tabStripLegibilityOverlay }
        // MARK: - Tab strip content
        .safeAreaInset(edge: .bottom) {
            VStack {
                if true { debugBox }
                
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
    
    var debugBox: some View {
        VStack {
            Text("LuckTabView Debug").font(.footnote).frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.primary).bold()
                .opacity(0.76)
            
            HStack {
                Text("Tab View Behavior")
                Spacer()
                Picker("Tab View Behavior", selection: $tabStripBehavior) {
                    ForEach(LuckTabViewStripBehavior.allCases) { tab in Text(tab.rawValue) }
                }
            }
            
            Toggle("Slow Animations (local)", isOn: $isSlowmo)
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
        .background {
            Capsule().fill(BackgroundStyle.background)
        }
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
    
    @State private var collapsedSize: CGSize = .zero
    @State private var expandedSize:  CGSize = .zero
    private var tabStripContentHeight: CGFloat { !isExpanded ? collapsedSize.height : expandedSize.height }
    
    var body: some View {
        VStack {
            tabStripTopContent
            
            Color.clear
                .frame(height: tabStripContentHeight)
        }
        .overlay(alignment: .bottom) {
            VStack {
                if !isExpanded { collapsedView }
                else           { expandedView }
            }
            // FIXME: This has a slight jerkiness to it, as we get two changes when we expand:
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { expandedSize = $0 })
        }
    }
    
    @State var collapsedViewContentSize: CGSize = .zero
    
    var collapsedViewTabsIcon: String {
        if selectedTab.isSearch { return "chevron.backward" }
        return selectedTab.icon
    }
    
    var collapsedView: some View {
        MorphContainer {
            HStack {
                // MARK: - Compact tab button
                // TODO: optical alignment: this button should probably be slightly smaller than the search field
                LuckTabViewStripCompactButton(animNS: animNS, icon: collapsedViewTabsIcon) {
                    searchFieldFocusState = false
                    isExpanded = true
                }
                .zIndex(1) // TODO: maybe we should just have our custom button...
                
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
                .background{
                    MorphView(shape: Capsule()) {
                        Capsule().fill(.clear)
                    }
                    .matchedGeometryEffect(id: "luckTabViewStripExpandedViewBar", in: animNS)
                }
            }
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { collapsedSize = $0 })
            .padding(.top)
        } background: {
            Rectangle().fill(.background)
        }
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
    
    var expandedView: some View {
        HStack(spacing: 0) {
            let tabs = allTabs
                // Do not show the search tab when it isn't necessary (based on behavior mode):
                // Exception in CompactAsDefault mode to show it is When the search box is focused and we are on the search tab.
                .filter { tabStripBehavior != .CompactAsDefault || selectedTab.isSearch || !$0.isSearch }
            ForEach(tabs) { tab in
                LuckTabViewStripButton(
                    animNS: animNS,
                    isSelected: tab == selectedTab,
                    icon: tab.icon, title: tab.rawValue as! String,
                    action: { stripSelectTabAction(tab: tab) }
                )
                .onChange(of: selectedTab, onSelectedTabChanged)
                // @Behavior  smooth selection indicator position change when not collapsing:
                // FIXME: The SW keyboard causes some weird visuals as collapsedView sticks to the top
                .animation(tabStripBehavior != .CompactAsDefault && !searchFieldFocusState ? tabSelectionAnimation.speed(isSlowmo ? 0.1 : 1) : nil,
                           value: selectedTab)
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(.thinMaterial)
                .stroke(lightBorder, lineWidth: 1)
                .matchedGeometryEffect(id: "luckTabViewStripExpandedViewBar", in: animNS)
        }
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
