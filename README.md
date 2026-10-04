# Luck UI experiments

A SwiftUI tab bar and reusable Metal metaballs, keeping the floating capsules and spring choreography from the original experiment. Minimum deployment target: **iOS 18.4**.

Open `LuckUIExperiments.xcodeproj` and run the shared `LuckUIExperiments` scheme. The settings button in the demo exposes live destinations, bar behavior, optional search and player, right-to-left layout, Reduce Motion, and slow animations. Live destinations let you check scrolling, navigation, per-tab state, and search filtering.

## Using the tab view

For app integration guidance, see [Docs/LuckTabView.md](Docs/LuckTabView.md).

`LuckTabView` takes stable, typed destinations and a selection binding. Each destination owns its navigation and content. The underlying SwiftUI `TabView` preserves destination state while the custom bar handles presentation.

```swift
enum Destination: Hashable { case home, library, search }

struct AppTabs: View {
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
            NavigationStack {
                List {
                    switch destination {
                    case .home: Text("Home")
                    case .library: Text("Library")
                    case .search: Text(query.isEmpty ? "Search your library" : query)
                    }
                }
                .luckTabBarScrollTracking()
            }
        }
    }
}
```

Use one to five tabs with unique IDs and at most one `.search` role. Keep IDs stable when changing titles or badges. Removing the selected destination selects the first remaining tab. Search is optional; without it, the compact capsule shows the selected title and expands the tabs when tapped.

Drag horizontally from the compact circle to open the tabs, or drag across the expanded strip. The indicator follows your finger; releasing selects the nearest tab. Moving away vertically before releasing cancels selection and leaves the strip open. At accessibility text sizes, drag the selected indicator to select another tab; swipe other tabs to scroll the row.

| Behavior | Presentation |
| --- | --- |
| `.compactAsDefault` | Starts compact and compacts after selecting a tab. Search stays in the compact field, so the expanded strip omits its redundant button unless Search is selected. |
| `.compactOnSearch` | Starts expanded; selecting or focusing Search compacts the bar. |
| `.compactOnScroll` | Also compacts when scrolling down and expands when scrolling up. Attach `.luckTabBarScrollTracking()` to each destination's primary vertical `List` or `ScrollView`. |

Provide `searchText` to share the query with your app. If omitted, the control owns it and exposes its value through `@Environment(\.luckSearchText)`. Focusing the field selects Search; changing tabs retains the query. Expanding the tabs dismisses the keyboard.

An optional `accessory` builder places your own content above the bar:

```swift
LuckTabView(tabs: tabs, selection: $selection) { destination in
    destinationView(destination)
} accessory: { placement in
    PlayerView(isCompact: placement == .compact)
}
```

The builder receives `.compact` or `.expanded`. The accessory keeps its own intrinsic height and participates in the bottom safe area. The demo's player is an example, not part of the reusable control.

Destinations have separate hosting boundaries for consistent iPad safe areas. Put navigation and consumers of destination preferences inside the content closure. Environment values and animation transactions are forwarded.

System Reduce Motion, Reduce Transparency, Dynamic Type, and layout direction are respected. At accessibility text sizes, the expanded strip scrolls horizontally. You can additionally set `.environment(\.luckTabBarReduceMotion, true)`, or inspect the choreography with `.environment(\.luckTabBarAnimationSpeed, 0.1)`.

To use the component in another app target, copy the three files in `Controls/`, `Effects/XZMorphUI_SDF/XZMorphUI_SDF.swift`, and the three files in `Shaders/SDF_morph/`. Include the `.metal` file in that target's build sources. No third-party dependency or private API is required by the component.

## Metaballs and animation

An active-only display link samples a SwiftUI `KeyframeTimeline` for the circle, capsule, icons, search field, and staggered labels. Interrupted transitions restart from the presented frame and velocity. The tab mask receives those values directly. The display link requests 120 Hz and stops when the animation finishes; the system controls the actual refresh rate. The selection indicator follows drag input directly and uses a short spring when released.

`SDFMorphMask` draws circles, capsules, and rounded rectangles using signed distances and a smooth union in Metal. It has an explicit 32-byte entity format, validates geometry before upload, and antialiases the contour using pixel derivatives. It does not need blend modes, blurred alpha thresholds, or layer texture samples to join shapes.

For other layouts, mark clear shapes with `.morphable(shape:intensity:)` and wrap their parent in `.morphContainer(background:)`:

```swift
HStack(spacing: 8) {
    Circle().fill(.clear).frame(width: 60, height: 60)
        .morphable(shape: .circle, intensity: 24)
    Capsule().fill(.clear).frame(width: 120, height: 60)
        .morphable(shape: .capsule, intensity: 24)
}
.padding(24)
.morphContainer(background: .blue)
```

Intensity is the joining distance in points. Leave space around shapes for the join. This convenience path resolves anchors in the container's local coordinates; nested containers consume their own anchors. For an animation with known geometry, use `SDFMorphMask(entities:)` directly, as the tab bar does.

The screenshot's `CASDFLayer`, `CASDFElementLayer`, and `CASDFFillEffect` are private APIs, present in the inspected iOS 26.5 runtime as well as the newer SDK. Their first release was not established. Public [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer) supports joining Liquid Glass on iOS 26, but changes the visual treatment and cannot cover iOS 18.4. This project keeps its own renderer across supported versions. The older blur/blending experiments remain separate from the tab component.

## Checks and boundaries

Run the shared scheme's UI tests on an iOS simulator. They cover animated expansion/collapse, drag selection and cancellation, selection bindings, independent destination state and navigation, search focus and query retention, hidden controls, removing selected tabs/accessories, bottom-content clearance, bounce handling, and scroll compaction in right-to-left layout.

```sh
python3 Tests/check-animation.py
python3 Tests/check-sdf.py
xcodebuild -project LuckUIExperiments.xcodeproj -scheme LuckUIExperiments \
  -destination 'platform=iOS Simulator,name=Luck iPhone 16 iOS 18.4' test
```

The Python checks require macOS with Xcode selected. They exercise the actual SwiftUI keyframe definitions and compiled Metal geometry, including repeated transitions, positional continuity at interruptions, isolated shapes, touching shapes, and smooth unions. The timeline checks do not model inherited velocity during a running animation; simulator recordings are also used to inspect the connected motion.

This is a bottom-bar component for iPhone and iPad, not a replacement for every system tab feature. It does not provide sidebar adaptation, user tab customization, overflow tabs, the system's inline bottom accessory, or native Liquid Glass scroll-edge effects. The simulator can verify interaction and rendered geometry; physical-device frame pacing and VoiceOver usage still need device testing.
