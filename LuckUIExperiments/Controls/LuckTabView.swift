// LuckUIExperiments::LuckTabView.swift - 11/04/2025

import SwiftUI

protocol LuckNavigationDestination: CaseIterable, Identifiable, RawRepresentable
where AllCases == Array<Self>, RawValue: StringProtocol {
    var id: Self { get }
    
    associatedtype Content: View
    @ViewBuilder func view() -> Content
    
    var icon: String { get }
}

extension LuckNavigationDestination {
    var id: Self { self }
    
    var icon: String { get { return "gear" } }
}

private struct LuckSearchTextEnvironmentKey: EnvironmentKey {
    static let defaultValue: String = ""
}

private struct LuckTabViewAnimationKey: EnvironmentKey {
    static let defaultValue: Animation = .default
}

extension EnvironmentValues {
    var luckSearchText: String {
        get { self[LuckSearchTextEnvironmentKey.self] }
        set { self[LuckSearchTextEnvironmentKey.self] = newValue }
    }
    
    var luckTabViewAnimation: Animation {
        set { self[LuckTabViewAnimationKey.self] = newValue }
        get { self[LuckTabViewAnimationKey.self] }
    }
}

struct LuckTabView<Tab: LuckNavigationDestination>: View {
    // MARK: - Tabs
    var tabs: Tab.Type
    
    @State var internalSelection: Tab
    var externalSelection: Binding<Tab>?
    
    var selectionBinding: Binding<Tab> { externalSelection ?? $internalSelection }
    
    var selection: Tab { selectionBinding.wrappedValue }
    func setSelection(_ tab: Tab) { selectionBinding.wrappedValue = tab }
    
    let allTabs: Array<Tab>
    
    init(tabs: Tab.Type, selection: Binding<Tab>? = nil) {
        self.tabs = tabs
        self.allTabs = tabs.allCases
        
        if let selection = selection {
            self.externalSelection = selection
        }
        self._internalSelection = State(initialValue: allTabs.first!) // TODO: check if none!
    }
    
    // MARK: -
    @Namespace var animNamespace
    @Environment(\.colorScheme) var colorScheme
    
    let idleHeight    : CGFloat = 50
    let expandedHeight: CGFloat = 70
    
    @State var isExpanded = false
    
    @State var searchText: String = ""
    @FocusState var searchFocusState: Bool
    
    @State var isSlowmo = true
    var animation: Animation { !isSlowmo ? normalAnimation : normalAnimation.speed(0.2) }
    
//    var slowAnimation:   Animation { Animation.spring(response: 10, dampingFraction: 0.83) }
    var normalAnimation: Animation { Animation.spring(response: 0.4, dampingFraction: 0.83) }
    
    @State var tabStripSize: CGSize = .zero
    
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
        .padding(.horizontal)
    }
    
    var body: some View {
        Group {
            allTabs.first(where: { $0 == selection })?.view()
                .environment(\.luckSearchText, searchText)
            
                .onLongPressGesture(minimumDuration: 0.5) { isSlowmo.toggle() }
                .sensoryFeedback(.increase, trigger: isSlowmo)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: tabStripSize.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            Group {}
                .safeAreaInset(edge: .bottom) {
                    VStack {
                        customTopInset
                        
                        if !isExpanded { idle }
                        else           { expanded }
                    }
                    .padding(8)
                    .padding(.top, 32) // More blur towards the top
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.08), radius: 4)
                    .onGeometryChange(for: CGSize.self, of: { $0.size }) { size in
                        tabStripSize = size
                    }
                }
                .background {
                    ZStack {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .opacity(0.3)
                        
                        VariableBlurView(maxBlurRadius: 4, direction: .blurredBottomClearTop, startOffset: 0)
                    }
                    .ignoresSafeArea()
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
    
    @State var searchPreviousTab: Tab? = nil
    
    // MARK: - Idle view
    var idle: some View {
        MorphContainer(blurRadiusMult: 1) {
            HStack(spacing: 15) {
                MorphView() {
                    LuckTabButton(animNamespace: animNamespace, isCompact: true, isSelected: true, showFill: false, action: { searchFocusState = false; withAnimation(animation) { isExpanded.toggle() } }
                    ) {
                        Label(selection.rawValue, systemImage: selection.icon != "magnifyingglass" ? selection.icon : searchPreviousTab?.icon ?? "ellipsis" )
                    }
                } shape: {
                    Capsule().matchedGeometryEffect(id: "ActiveTabButton", in: animNamespace)
                }
                .environment(\.luckTabViewAnimation, animation)
                .zIndex(1)
                
#if false
                MorphView {
                    Capsule().fill(.clear)
                } shape: {
                    Capsule()
                }
                .matchedGeometryEffect(id: "TabBar", in: animNamespace)
#else
                MorphView(shape: Capsule()) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                        TextField("Artists, Songs, Lyrics and More", text: $searchText)
                            .focused($searchFocusState, equals: true)
                            .onChange(of: searchFocusState) { oldValue, newValue in
                                if newValue {
                                    let searchTab = allTabs.filter { $0.icon == "magnifyingglass" }.first
                                    if let searchTab = searchTab {
                                        if selection != searchTab { searchPreviousTab = selection }
                                        selectTab(tab: searchTab)
                                    }
                                } else {
                                    if let prevTab = searchPreviousTab ?? allTabs.first {
                                        selectTab(tab: prevTab)
                                    }
                                }
                            }
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal)
                    .frame(maxHeight: .infinity)
                    .background() {
                        Capsule().fill(.clear)
                    }
                }
                .matchedGeometryEffect(id: "TabBar", in: animNamespace)
                .frame(height: idleHeight)
#endif
            }
            .padding() // TODO: This padding seems very important for the matched geometry effect to work on the search field... why?!
        } background: {
            if colorScheme == .light { Rectangle().fill(BackgroundStyle.background) }
            else                     { Rectangle().fill(Material.bar) }
        }
        .frame(height: idleHeight)
    }
    
    // MARK: - Expanded view
    func selectTab(tab: Tab) {
        let isSearchTab = tab.icon == "magnifyingglass"
        
        if true || !isSearchTab { selectionBinding.wrappedValue = tab }
        
        withAnimation(animation) { isExpanded = false } completion: {
            if isSearchTab { searchFocusState = true }
        }
    }
    
    var expanded: some View {
        HStack(spacing: 26) {
            ForEach(allTabs.filter { $0.icon != "magnifyingglass" }) { tab in
                LuckTabButton(animNamespace: animNamespace, isCompact: false, isSelected: tab == selection,
                              action: { selectTab(tab: tab) }
                ) {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: expandedHeight)
        .background {
            Capsule()
                .fill(.thinMaterial)
//                .fill(.clear)
                .strokeBorder(lightBorder, lineWidth: 1.5)
                .onTapGesture { withAnimation(animation) { isExpanded = false } }
                .matchedGeometryEffect(id: "TabBar", in: animNamespace)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
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
        .blendMode(colorScheme == .light ? .hardLight : .overlay)
    }
}
