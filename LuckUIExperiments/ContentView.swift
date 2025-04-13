// LuckUIExperiments::ContentView.swift - 10/04/2025

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

extension EnvironmentValues {
    var luckSearchText: String {
        get { self[LuckSearchTextEnvironmentKey.self] }
        set { self[LuckSearchTextEnvironmentKey.self] = newValue }
    }
}

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
    }
    
    @State var selectedTab: Tabs = .library
    
    var body: some View {
        VStack {
            LuckTabView(tabs: Tabs.self, selection: $selectedTab)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
