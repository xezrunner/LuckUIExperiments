// LuckUIExperiments::LuckTabView.swift - 11/04/2025

import SwiftUI

protocol LuckNavigationDestination: CaseIterable, Identifiable, Equatable, RawRepresentable
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

extension EnvironmentValues {
    @Entry var luckSearchText: String = ""
    @Entry var luckTabViewAnimation: Animation = .default // TODO: remove?
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
    }
    
    @State private var isTabStripExpanded: Bool = false
    @State private var searchFieldText: String = ""
    
    var body: some View {
        // MARK: - Tab content
        Group {
            selection.view()
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
            }
            .padding(24)
            // MARK: - Tab strip state animation
            .animation(.spring(response: 0.4, dampingFraction: 0.83).speed(isSlowmo ? 0.1 : 1), value: isTabStripExpanded)
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
            HStack {
                Text("Behavior")
                Spacer()
                Picker("Behavior", selection: $tabStripBehavior) {
                    ForEach(LuckTabViewStripBehavior.allCases) { tab in Text(tab.rawValue) }
                }
            }
            
            Toggle("Slow Motion Animations", isOn: $isSlowmo)
            Toggle("Is Tab Strip Expanded", isOn: $isTabStripExpanded)
        }
        .monospaced()
        .font(.system(size: 14))
        .padding()
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 12))
    }
}

fileprivate struct LuckTabViewStrip<Tab: LuckNavigationDestination>: View {
    var animNS: Namespace.ID
    
    public var allTabs: Array<Tab>
    @Binding public var selectedTab: Tab
    
    @Binding public var tabStripBehavior: LuckTabViewStripBehavior
    
    @Binding public var isExpanded: Bool
    
    @Binding public var searchFieldText: String
    
    // TODO: custom
    var tabStripTopContent: some View {
        VStack {
            Text("< top content >")
                .padding()
                .background(.gray)
        }
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
    var collapsedView: some View {
        MorphContainer {
            HStack {
                // MARK: - Compact tab button
                // TODO: optical alignment: this button should probably be slightly smaller than the search field
                LuckTabViewStripCompactButton(animNS: animNS, icon: selectedTab.icon) {
                    isExpanded = true
                }
                .zIndex(1) // TODO: maybe we should just have our custom button...
                
                // MARK: - Search field  @Behavior
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Artists, Songs, Lyrics and More", text: $searchFieldText) // TODO: placeholder parameter
                        .font(.system(size: 14))
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
    
    var expandedView: some View {
        HStack(spacing: 0) {
            let tabs = allTabs.filter { $0.icon != "magnifyingglass" }
            ForEach(tabs) { tab in
                LuckTabViewStripButton(animNS: animNS, isSelected: tab == selectedTab,
                                       icon: tab.icon, title: tab.rawValue as! String,
                                       action: {
                    if selectedTab == tab { isExpanded = false } // HACK: @Behavior
                    selectedTab = tab
                })
                .onChange(of: selectedTab, { isExpanded = false })
                // .animation(.smooth, value: selectedTab) // @Behavior  smooth selection indicator position change
            }
        }
        .padding(4)
        .background {
            Capsule().fill(.thinMaterial)
                .matchedGeometryEffect(id: "luckTabViewStripExpandedViewBar", in: animNS)
        }
    }
}

#Preview {
    ContentView()
}
