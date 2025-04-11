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

struct LibraryTabView: View {
    let array = [
        "Time",
        "Heaven Takes You Home",
        "Jacob's Note",
        "Moth to a Flame",
        "Mafia",
        "Frankenstein",
        "Don't Go Mad",
        "Paradise Again",
        "Lifetime",
        "Calling On",
        "Home",
        "It Gets Better",
        "Redlight",
        "Can U Feel It",
        "19:30",
        "Another Minute",
        "For You"
    ]
    
    @Environment(\.luckSearchText) var searchText
    
    var body: some View {
        List {
            ForEach(
                array.filter { $0.lowercased().starts(with: searchText.lowercased()) },
                id: \.self)
            { it in
                Text(it)
            }
        }
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
        
        @ViewBuilder func view() -> some View {
            switch self {
            case .library: LibraryTabView()
            default: Text("< \(rawValue) >")
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
