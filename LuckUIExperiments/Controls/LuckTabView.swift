// LuckUIExperiments::LuckTabView.swift - 11/04/2025

import SwiftUI

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
    @Namespace var animNS
    
    let idleHeight    : CGFloat = 50
    let expandedHeight: CGFloat = 70
    
    @State var isExpanded = false
    
    @State var searchText: String = ""
    @FocusState var searchFocusState: Bool
    
    #if false
    let animation = Animation.smooth(duration: 3)
    #else
    let animation = Animation.spring(response: 0.4, dampingFraction: 0.80)
    #endif
    
    var body: some View {
        Group {
            allTabs.first(where: { $0 == selection })?.view()
                .environment(\.luckSearchText, searchText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            Group {}
                .safeAreaInset(edge: .bottom) {
                    Group {
                        if !isExpanded { idle }
                        else           { expanded }
                    }
                    .padding()
                    .padding(.top, 32) // More blur towards the top
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.08), radius: 4)
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
    
    // MARK: - Idle view
    var idle: some View {
        HStack(spacing: 14) {
            LuckTabButton(animNS: animNS, isCompact: true, isSelected: true,
                          action: { withAnimation(animation) { isExpanded.toggle() } }
            ) {
                Label(selection.rawValue, systemImage: selection.icon)
            }
            .zIndex(1)
            
#if false
            Capsule().fill(.background)
                .matchedGeometryEffect(id: "TabBar", in: animNS)
#else
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
                    .focused($searchFocusState, equals: true)
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity)
            .background() {
                Capsule().fill(.background)
                    .matchedGeometryEffect(id: "TabBar", in: animNS)
            }
#endif
        }
        .padding(.horizontal)
        .frame(height: idleHeight)
    }
    
    // MARK: - Expanded view
    func selectTab(tab: Tab) {
        let isSearchTab = tab.icon == "magnifyingglass"
        
        if !isSearchTab { selectionBinding.wrappedValue = tab }
        withAnimation(animation) { isExpanded.toggle() } completion: {
            if isSearchTab { searchFocusState = true }
        }
    }
    
    var expanded: some View {
        HStack {
            ForEach(allTabs) { tab in
                LuckTabButton(animNS: animNS, isCompact: false, isSelected: tab == selection,
                              action: { selectTab(tab: tab) }
                ) {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: expandedHeight)
        
        .background {
            Capsule()
                .fill(.thinMaterial)
                .strokeBorder(lightBorder, lineWidth: 1.5)
                .matchedGeometryEffect(id: "TabBar", in: animNS)
                .onTapGesture { withAnimation(animation) { isExpanded = false } }
        }
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
        .blendMode(.hardLight)
    }
}
