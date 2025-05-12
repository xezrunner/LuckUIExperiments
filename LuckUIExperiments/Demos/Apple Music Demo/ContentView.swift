// LuckUIExperiments::ContentView.swift - 10/04/2025

import SwiftUI

struct ContentView: View {
    @Namespace var CVanimNS
    
    @State var searchText = ""
    
    enum Tabs: String, LuckNavigationDestination {
        case home    = "Home"
        case new     = "New"
        case radio   = "Radio"
        case library = "Library"
        case search  = "Search"
        
        var tabScreenshot: ImageResource {
            switch self {
            case .home:
                    .TabScreenshots.home
            case .new:
                    .TabScreenshots.new
            case .radio:
                    .TabScreenshots.radio
            case .library:
                    .TabScreenshots.library
            case .search:
                    .TabScreenshots.search
            }
        }
        
        @ViewBuilder func view() -> some View {
            switch self {
#if false
            case .home: List {
                ForEach(0..<50, id: \.self) { it in Text(it.description) }
            }
#endif
            default: ScrollView {
                Image(tabScreenshot).resizable().aspectRatio(
                    contentMode: .fill
                )
            }.ignoresSafeArea()
            }
        }
        
        var icon: String {
            switch self {
            case .home:    "house"
            case .new:     "square.grid.2x2.fill"
            case .radio:   "dot.radiowaves.left.and.right"
            case .library: "square.stack.fill"
            case .search:  "magnifyingglass"
            }
        }
        
        var isSearch: Bool { self == .search }
    }
    
    @State var selectedTab: Tabs = .home
    
    var body: some View {
        VStack {
            LuckTabView(tabType: Tabs.self, tabSelection: $selectedTab)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
