# Using LuckTabView in an app

`LuckTabView` is the root container for a tab-based app on iPhone and iPad. It replaces the system tab bar with a floating bar that can collapse into a compact circle and capsule, and optionally hosts a search field and an accessory such as a mini player. It requires iOS 18.4.

The control owns presentation: the bar, its expansion state, the search field, and the bottom safe area. Your app owns everything else: which destinations exist, which one is selected, the search query if you need it outside the control, and each destination's content and navigation.

```
LuckTabView
├── SwiftUI TabView (system bar hidden, keeps per-destination state)
│   └── one hosting controller per destination
│       └── your content(destination), e.g. NavigationStack { ... }
└── bottom overlay
    ├── accessory(placement)   optional, your view
    └── LuckTabBar             expanded strip or compact circle + capsule
```

## Adding it to a target

Copy these files into the app target:

- `LuckUIExperiments/Controls/LuckTabView.swift`, `LuckTabBar.swift`, `LuckTabButton.swift`
- `LuckUIExperiments/Effects/XZMorphUI_SDF/XZMorphUI_SDF.swift`
- `LuckUIExperiments/Shaders/SDF_morph/metaball_sdf.metal`, `metaball_sdf_common.h`, `metaball_sdf_shapes.h`

The `.metal` file must be in the target's Compile Sources so the default Metal library contains the mask shader. There are no package dependencies and no private API.

## Minimal setup

Make `LuckTabView` the root of the scene, not a child of a `NavigationStack`. Describe destinations with a `Hashable` type, usually an enum, and keep the selection in your own state.

```swift
enum Destination: Hashable { case home, library, search }

struct RootView: View {
    @State private var selection = Destination.home
    @State private var query = ""

    private let tabs = [
        LuckTab(Destination.home, title: "Home", systemImage: "house"),
        LuckTab(Destination.library, title: "Library", systemImage: "books.vertical", badge: "3"),
        LuckTab(Destination.search, title: "Search", systemImage: "magnifyingglass", role: .search)
    ]

    var body: some View {
        LuckTabView(tabs: tabs, selection: $selection,
                    behavior: .compactOnSearch, searchText: $query) { destination in
            switch destination {
            case .home: HomeScreen()
            case .library: LibraryScreen()
            case .search: SearchScreen(query: query)
            }
        }
    }
}

struct HomeScreen: View {
    var body: some View {
        NavigationStack {
            List { /* ... */ }
                .luckTabBarScrollTracking()
                .navigationTitle("Home")
        }
    }
}
```

## Rules for the tab list

The initializer traps if these are violated:

- Use one to five tabs.
- Every tab ID must be unique.
- Mark at most one tab with `role: .search`.

Keep IDs stable. Title, icon, and badge can change freely; an ID change is treated as a different destination and loses its state. You can add or remove tabs at runtime. If the selected tab disappears, selection moves to the first remaining tab.

`badge` is a short string such as `"3"` or `"New"`. VoiceOver reads it as the tab's value. Pass `nil` to hide it.

## Writing destination content

Each destination is a full screen. Treat the content closure like the body of a `Tab` in a system `TabView`:

- Put `NavigationStack`, toolbars, `.navigationTitle`, sheets, and anything that reads preferences inside the closure. Each destination runs in its own hosting controller, so preferences do not reach views outside `LuckTabView`.
- Keep destination state in the destination's views (`@State`, `@StateObject`) or in your models. Switching tabs keeps it, including the navigation path and scroll position.
- Environment values and animation transactions from outside `LuckTabView` are forwarded into destinations, so app-wide `.environment(...)` and model injection work as usual.
- Do not add your own bottom padding for the bar. The control reserves the bar and accessory height as bottom safe area. Lists and scroll views scroll behind the bar and keep their last rows reachable. Ignore the bottom safe area only for backgrounds that should bleed under it.

## Choosing a behavior

| Behavior | Starts | Compacts when | Expands when |
| --- | --- | --- | --- |
| `.compactAsDefault` (default) | compact | a tab is selected | the user taps or drags the compact circle |
| `.compactOnSearch` | expanded | Search is selected or the search field is focused | the user taps the circle |
| `.compactOnScroll` | expanded | Search is focused or the user scrolls down | the user scrolls up or taps the circle |

`.compactAsDefault` suits apps where the content should dominate and tab switching is occasional. `.compactOnSearch` behaves closest to a standard tab bar. `.compactOnScroll` suits feeds and long lists.

For `.compactOnScroll`, attach `.luckTabBarScrollTracking()` to the primary vertical `List` or `ScrollView` of each destination. Without it that destination never compacts on scroll. Bounces at the top and bottom edges are ignored. Attaching the modifier under other behaviors is harmless, so it is fine to add it everywhere.

Changing `behavior` at runtime resets the bar to that behavior's starting state.

## Search

Search is optional. Without a `.search` tab, the compact capsule shows the selected tab's title and expands the bar when tapped.

With a `.search` tab, the compact capsule becomes a search field. Focusing it selects the Search tab and compacts the bar; expanding the bar dismisses the keyboard. The query survives tab changes.

There are two ways to read the query:

- Pass `searchText: $query` when the app needs the query itself, for example to drive a model, persist it, or clear it from code.
- Omit `searchText` to let the control own it, and read it inside destinations with `@Environment(\.luckSearchText)`.

`searchPrompt` sets the placeholder, for example `"Artists, Songs, Lyrics and More"`.

Setting `selection` to the Search tab from code compacts the bar but does not focus the field or show the keyboard. Selecting Search through the bar focuses it.

## Accessory

The `accessory` builder places your view above the bar, for example a mini player or a status banner:

```swift
LuckTabView(tabs: tabs, selection: $selection) { destination in
    destinationView(destination)
} accessory: { placement in
    if let track = player.current {
        MiniPlayer(track: track, isCompact: placement == .compact)
    }
}
```

`placement` is `.expanded` or `.compact` and follows the bar, so the accessory can drop secondary controls when the bar collapses. The accessory keeps its intrinsic size, sits in the same column as the bar (at most 600 points wide), and is included in the reserved bottom safe area. Return nothing to remove it; the space closes up. Style it yourself; the control draws no background for it.

## Accessibility and motion

The control respects system Reduce Motion, Reduce Transparency, Dynamic Type, and right-to-left layout without extra setup. At accessibility text sizes, the expanded strip scrolls horizontally.

Two environment values tune the animation:

- `.environment(\.luckTabBarReduceMotion, true)` disables the choreography even when the system setting is off, for example from an in-app preference.
- `.environment(\.luckTabBarAnimationSpeed, 0.1)` slows the animation for inspection. Values below 0.1 are clamped. Leave it at 1 in shipping builds.

## UI testing

The bar exposes stable accessibility identifiers:

| Identifier | Element |
| --- | --- |
| `luck.tab.<id>` | a tab button in the expanded strip; `<id>` is `String(describing:)` of the tab ID, so `luck.tab.home` for `Destination.home` |
| `luck.tabs.expand` | the compact circle that expands the bar |
| `luck.search` | the search text field |

Tab buttons report `isSelected`. Elements of the hidden state, compact or expanded, are removed from the accessibility tree, so check `exists` rather than visibility. `LuckUIExperimentsUITests/LuckTabViewUITests.swift` has working examples.

## Limits

This is a bottom tab bar. It does not provide sidebar adaptation on iPad, user tab customization, a "More" overflow for more than five tabs, the system bottom accessory API, or Liquid Glass scroll-edge effects. If an app needs those, use the system `TabView`.
