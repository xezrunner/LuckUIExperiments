import SwiftUI
import UIKit

public enum LuckTabRole {
    case tab
    case search
}

/// A stable destination. Keep its ID unchanged when its title or badge changes.
public struct LuckTab<ID: Hashable>: Identifiable {
    public var id: ID
    public var title: LocalizedStringKey
    public var systemImage: String
    public var role: LuckTabRole
    public var badge: String?

    public init(_ id: ID, title: LocalizedStringKey, systemImage: String,
                role: LuckTabRole = .tab, badge: String? = nil) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.badge = badge
    }
}

public enum LuckTabViewStripBehavior: String, CaseIterable, Identifiable {
    public var id: Self { self }
    case compactOnSearch
    case compactOnScroll
    case compactAsDefault
}

public enum LuckTabAccessoryPlacement {
    case expanded
    case compact
}

/// A floating bottom tab bar with the experiment's spring and metaball animation.
/// Use one to five destinations. Mark at most one as search. Content owns its navigation.
public struct LuckTabView<Selection: Hashable, Content: View, Accessory: View>: View {
    private let tabs: [LuckTab<Selection>]
    @Binding private var selection: Selection
    private let behavior: LuckTabViewStripBehavior
    private let searchPrompt: LocalizedStringKey
    private let externalSearchText: Binding<String>?
    private let content: (Selection) -> Content
    private let accessory: (LuckTabAccessoryPlacement) -> Accessory

    @State private var localSearchText = ""
    @State private var isExpanded: Bool
    @State private var accessoryHeight: CGFloat = 0
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.luckTabBarReduceMotion) private var requestedReduceMotion
    @Environment(\.luckTabBarAnimationSpeed) private var animationSpeed
    @Environment(\.self) private var contentEnvironment
    @ScaledMetric(relativeTo: .footnote) private var scaledExpandedHeight: CGFloat = 68
    @ScaledMetric(relativeTo: .body) private var scaledCompactHeight: CGFloat = 52

    public init(tabs: [LuckTab<Selection>], selection: Binding<Selection>,
                behavior: LuckTabViewStripBehavior = .compactAsDefault,
                searchText: Binding<String>? = nil,
                searchPrompt: LocalizedStringKey = "Search",
                @ViewBuilder content: @escaping (Selection) -> Content,
                @ViewBuilder accessory: @escaping (LuckTabAccessoryPlacement) -> Accessory) {
        precondition((1...5).contains(tabs.count), "LuckTabView requires one to five tabs.")
        precondition(Set(tabs.map(\.id)).count == tabs.count, "Tab IDs must be unique.")
        precondition(tabs.filter { $0.role == .search }.count <= 1, "Use at most one search tab.")
        self.tabs = tabs
        _selection = selection
        self.behavior = behavior
        self.searchPrompt = searchPrompt
        externalSearchText = searchText
        self.content = content
        self.accessory = accessory
        _isExpanded = State(initialValue: behavior != .compactAsDefault &&
                            tabs.first(where: { $0.id == selection.wrappedValue })?.role != .search)
    }

    private var selectedTab: LuckTab<Selection> {
        tabs.first { $0.id == selection } ?? tabs[0]
    }

    private var searchText: Binding<String> { externalSearchText ?? $localSearchText }
    private var layoutAnimation: Animation? {
        systemReduceMotion || requestedReduceMotion ? nil :
            .spring(response: 0.4, dampingFraction: 0.83).speed(max(0.1, animationSpeed))
    }
    private var controlsHeight: CGFloat {
        // NOTE: Reserve the bar's target height, not its animated presentation height.
        let barHeight = isExpanded ? expandedHeight : compactHeight
        return barHeight + 16 + (accessoryHeight > 0 ? accessoryHeight + 8 : 0)
    }
    private var expandedHeight: CGFloat { min(max(scaledExpandedHeight, 68), 112) }
    private var compactHeight: CGFloat { min(scaledCompactHeight, 80) }
    private var validSelection: Binding<Selection> {
        Binding(get: { selectedTab.id }, set: { selection = $0 })
    }

    public var body: some View {
        TabView(selection: validSelection) {
            ForEach(tabs) { tab in
                Tab(value: tab.id) {
                    LuckTabContent(content: content(tab.id)
                        .environment(\.luckSearchText, searchText.wrappedValue)
                        .onPreferenceChange(LuckTabScrollPreference.self) { event in
                            guard tab.id == selection, behavior == .compactOnScroll,
                                  selectedTab.role != .search, let event else { return }
                            isExpanded = !event.compact
                        }, environment: contentEnvironment, bottomInset: controlsHeight)
                        .animation(layoutAnimation, value: controlsHeight)
                        .toolbarVisibility(.hidden, for: .tabBar)
                } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                }
            }
        }
        .tabViewStyle(.tabBarOnly)
        .environment(\.luckSearchText, searchText.wrappedValue)
        .overlay(alignment: .bottom) {
            VStack(spacing: accessoryHeight > 0 ? 8 : 0) {
                // NOTE: The wrapper still reports zero when the accessory becomes EmptyView.
                VStack(spacing: 0) {
                    accessory(isExpanded ? .expanded : .compact)
                }
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    Color.clear
                        .onGeometryChange(for: CGFloat.self) { geometry in
                            geometry.size.height
                        } action: { height in
                            accessoryHeight = height
                        }
                        .transaction { $0.animation = nil }
                }
                LuckTabBar(tabs: tabs, selection: selection, behavior: behavior,
                           isExpanded: isExpanded, expandedHeight: expandedHeight,
                           compactHeight: compactHeight, searchText: searchText,
                           searchPrompt: searchPrompt, searchFocused: $searchFocused,
                           select: select, expand: expand)
            }
            .animation(layoutAnimation, value: isExpanded)
            .frame(maxWidth: 600)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(alignment: .bottom) {
                Rectangle().fill(.ultraThinMaterial)
                    .mask {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    }
                    .padding(.top, -32)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: selection) { _, _ in
            if selectedTab.role == .search || behavior == .compactAsDefault { isExpanded = false }
            if selectedTab.role != .search { searchFocused = false }
        }
        .onChange(of: searchFocused) { _, focused in
            guard focused, let search = tabs.first(where: { $0.role == .search }) else { return }
            selection = search.id
            isExpanded = false
        }
        .onChange(of: behavior) { _, new in
            isExpanded = new != .compactAsDefault && selectedTab.role != .search
        }
        .onChange(of: tabs.map(\.id), initial: true) { _, ids in
            if !ids.contains(selection) { selection = tabs[0].id }
        }
        .onChange(of: tabs.first(where: { $0.role == .search })?.id) { _, _ in
            searchFocused = false
        }
    }

    private func select(_ id: Selection) {
        selection = id
        let isSearch = tabs.first { $0.id == id }?.role == .search
        if isSearch || behavior == .compactAsDefault { isExpanded = false }
        searchFocused = isSearch
    }

    private func expand() {
        searchFocused = false
        isExpanded = true
    }
}

// NOTE: iPad's native tab controller discards SwiftUI's surrounding bottom inset.
// A destination hosting controller passes the reserved space through UIKit's safe area,
// preserving full-size scrolling behind the controls and callers' own content margins.
private struct LuckTabContent<Content: View>: View, Animatable {
    let content: Content
    let environment: EnvironmentValues
    var bottomInset: CGFloat
    private let contentVersion = UUID()

    init(content: Content, environment: EnvironmentValues, bottomInset: CGFloat) {
        self.content = content
        self.environment = environment
        self.bottomInset = bottomInset
    }

    var animatableData: CGFloat {
        get { bottomInset }
        set { bottomInset = newValue }
    }

    var body: some View {
        LuckTabHostingController(content: content.environment(\.self, environment),
                                 bottomInset: bottomInset, contentVersion: contentVersion)
    }
}

private struct LuckTabHostingController<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let bottomInset: CGFloat
    let contentVersion: UUID

    func makeUIViewController(context: Context) -> UIHostingController<LuckTabHostedContent<Content>> {
        let controller = UIHostingController(rootView: LuckTabHostedContent(coordinator: context.coordinator))
        controller.view.backgroundColor = .clear
        controller.additionalSafeAreaInsets.bottom = bottomInset
        return controller
    }

    func updateUIViewController(_ controller: UIHostingController<LuckTabHostedContent<Content>>, context: Context) {
        // NOTE: Animation copies retain the version; only new parent inputs update content.
        if context.coordinator.contentVersion != contentVersion {
            let coordinator = context.coordinator
            let transaction = context.transaction
            let content = content
            let version = contentVersion
            coordinator.contentVersion = version
            // NOTE: Publish after the representable update, preserving the caller's transaction.
            DispatchQueue.main.async {
                guard coordinator.contentVersion == version else { return }
                withTransaction(transaction) {
                    coordinator.content = content
                }
            }
        }
        controller.additionalSafeAreaInsets.bottom = bottomInset
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content, contentVersion: contentVersion)
    }

    final class Coordinator: ObservableObject {
        @Published var content: Content
        var contentVersion: UUID

        init(content: Content, contentVersion: UUID) {
            self.content = content
            self.contentVersion = contentVersion
        }
    }
}

private struct LuckTabHostedContent<Content: View>: View {
    @ObservedObject var coordinator: LuckTabHostingController<Content>.Coordinator

    var body: some View { coordinator.content }
}

public extension LuckTabView where Accessory == EmptyView {
    init(tabs: [LuckTab<Selection>], selection: Binding<Selection>,
         behavior: LuckTabViewStripBehavior = .compactAsDefault,
         searchText: Binding<String>? = nil, searchPrompt: LocalizedStringKey = "Search",
         @ViewBuilder content: @escaping (Selection) -> Content) {
        self.init(tabs: tabs, selection: selection, behavior: behavior,
                  searchText: searchText, searchPrompt: searchPrompt, content: content,
                  accessory: { _ in EmptyView() })
    }
}

public extension EnvironmentValues {
    /// Also available when a caller lets LuckTabView own the search query.
    @Entry var luckSearchText = ""
    /// Disable the custom choreography in addition to the system Reduce Motion setting.
    @Entry var luckTabBarReduceMotion = false
    /// A local speed for inspecting the animation. Values below 0.1 are clamped.
    @Entry var luckTabBarAnimationSpeed: Double = 1
}

private struct LuckTabScrollEvent: Equatable {
    var bucket: Int
    var compact: Bool
}

private struct LuckTabScrollPreference: PreferenceKey {
    static var defaultValue: LuckTabScrollEvent? { nil }
    static func reduce(value: inout LuckTabScrollEvent?, nextValue: () -> LuckTabScrollEvent?) {
        value = nextValue() ?? value
    }
}

private struct LuckTabScrollTracking: ViewModifier {
    @State private var event: LuckTabScrollEvent?

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Int?.self) { geometry in
                let offset = geometry.contentOffset.y + geometry.contentInsets.top
                let maximum = max(0, geometry.contentSize.height + geometry.contentInsets.top +
                                  geometry.contentInsets.bottom - geometry.containerSize.height)
                // NOTE: Ignore bounce-back samples outside the content's scrollable range.
                guard offset >= 0, offset <= maximum else { return nil }
                return Int(offset / 16)
            } action: { old, new in
                guard let old, let new else { return }
                event = LuckTabScrollEvent(bucket: new, compact: new > 0 && new > old)
            }
            .preference(key: LuckTabScrollPreference.self, value: event)
    }
}

public extension View {
    /// Attach to the destination's primary vertical ScrollView or List to enable
    /// compactOnScroll. Downward scrolling minimizes; upward scrolling expands.
    func luckTabBarScrollTracking() -> some View {
        modifier(LuckTabScrollTracking())
    }
}
