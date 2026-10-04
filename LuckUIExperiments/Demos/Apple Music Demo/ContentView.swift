import SwiftUI

struct ContentView: View {
    enum Destination: String, CaseIterable {
        case home, new, radio, library, search

        var tab: LuckTab<Self> {
            switch self {
            case .home: LuckTab(self, title: "Home", systemImage: "house")
            case .new: LuckTab(self, title: "New", systemImage: "square.grid.2x2.fill")
            case .radio: LuckTab(self, title: "Radio", systemImage: "dot.radiowaves.left.and.right")
            case .library: LuckTab(self, title: "Library", systemImage: "square.stack.fill", badge: "3")
            case .search: LuckTab(self, title: "Search", systemImage: "magnifyingglass", role: .search)
            }
        }

        var screenshot: ImageResource {
            switch self {
            case .home: .TabScreenshots.home
            case .new: .TabScreenshots.new
            case .radio: .TabScreenshots.radio
            case .library: .TabScreenshots.library
            case .search: .TabScreenshots.search
            }
        }
    }

    @State private var selection: Destination = .home
    @State private var searchText = ""
    @State private var behavior = LuckTabViewStripBehavior.compactAsDefault
    @State private var showsSettings = false
    @State private var showsAccessory = true
    @State private var includesSearch = true
    @State private var liveContent = false
    @State private var reduceMotion = false
    @State private var slowMotion = false
    @State private var rightToLeft = false
    @State private var playing = false

    var body: some View {
        LuckTabView(tabs: Destination.allCases.filter { includesSearch || $0 != .search }.map(\.tab),
                    selection: $selection, behavior: behavior, searchText: $searchText,
                    searchPrompt: "Artists, Songs, Lyrics and More") { tab in
            if liveContent || tab == .search {
                MusicDemoDestination(destination: tab, searchText: searchText)
            } else {
                ScrollView {
                    Image(tab.screenshot)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel(Text(tab.tab.title))
                }
                .luckTabBarScrollTracking()
                .ignoresSafeArea(edges: .top)
            }
        } accessory: { placement in
            if showsAccessory { player(placement: placement) }
        }
        .environment(\.layoutDirection, rightToLeft ? .rightToLeft : .leftToRight)
        .environment(\.luckTabBarReduceMotion, reduceMotion)
        .environment(\.luckTabBarAnimationSpeed, slowMotion ? 0.1 : 1)
        .overlay(alignment: .topTrailing) {
            Button { showsSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: .circle)
            }
            .accessibilityLabel("Experiment settings")
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showsSettings) { settings }
    }

    private func player(placement: LuckTabAccessoryPlacement) -> some View {
        HStack(spacing: 16) {
            Image(.AlbumArtwork.paradiseagain)
                .resizable().scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(.rect(cornerRadius: 8))
            Text("Calling On").font(.subheadline).lineLimit(1)
            Spacer(minLength: 0)
            Button { playing.toggle() } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(playing ? "Pause" : "Play")
            Button {} label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Next track")
        }
        .tint(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.background, in: .capsule)
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Picker("Bar behavior", selection: $behavior) {
                    Text("Compact by default").tag(LuckTabViewStripBehavior.compactAsDefault)
                    Text("Compact on search").tag(LuckTabViewStripBehavior.compactOnSearch)
                    Text("Compact on scroll").tag(LuckTabViewStripBehavior.compactOnScroll)
                }
                Picker("Selected tab", selection: $selection) {
                    ForEach(Destination.allCases.filter { includesSearch || $0 != .search }, id: \.self) { tab in
                        Text(tab.tab.title).tag(tab)
                    }
                }
                Toggle("Live content", isOn: $liveContent)
                Toggle("Search tab", isOn: $includesSearch)
                Toggle("Player accessory", isOn: $showsAccessory)
                Toggle("Reduce motion", isOn: $reduceMotion)
                Toggle("Slow animations", isOn: $slowMotion)
                Toggle("Right to left", isOn: $rightToLeft)
                NavigationLink("Metaball playground") { Temp().navigationTitle("Metaballs") }
            }
            .navigationTitle("Experiment settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showsSettings = false }
                }
            }
        }
    }
}

private struct MusicDemoDestination: View {
    let destination: ContentView.Destination
    let searchText: String
    @State private var favorites = 0
    private let songs = ["Calling On", "Heaven Takes You Home", "Moth To A Flame", "Redlight", "Lifetime", "Don't You Worry Child"]

    var body: some View {
        NavigationStack {
            List {
                if destination != .search {
                    Button("Favorites: \(favorites)") { favorites += 1 }
                        .accessibilityIdentifier("demo.favorites")
                }
                ForEach(0..<8, id: \.self) { section in
                    Section(destination == .search ? "Results" : "Playlist \(section + 1)") {
                        ForEach(songs.filter { destination != .search || searchText.isEmpty || $0.localizedCaseInsensitiveContains(searchText) }, id: \.self) { song in
                            NavigationLink(song) {
                                Text(song).navigationTitle(song)
                            }
                        }
                    }
                }
                Text("End of library").accessibilityIdentifier("demo.end")
            }
            .luckTabBarScrollTracking()
            .navigationTitle(Text(destination.tab.title))
            .overlay {
                if destination == .search && !searchText.isEmpty && !songs.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
