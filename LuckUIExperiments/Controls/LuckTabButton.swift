import SwiftUI

struct LuckTabViewStripButton<ID: Hashable>: View {
    let tab: LuckTab<ID>
    let isSelected: Bool
    let isHighlighted: Bool
    let action: () -> Void
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 22))
                    .frame(height: 24)
                    .overlay(alignment: .topTrailing) {
                        if let badge = tab.badge {
                            Text(verbatim: badge)
                                .font(.caption2.weight(.semibold))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .background(.red, in: .capsule)
                                .offset(x: layoutDirection == .rightToLeft ? -12 : 12, y: -5)
                                .accessibilityHidden(true)
                        }
                    }
                Text(tab.title)
                    .font(.footnote)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHighlighted ? Color.accentColor : Color.secondary)
        .accessibilityLabel(Text(tab.title))
        .accessibilityValue(Text(verbatim: tab.badge ?? ""))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("luck.tab.\(String(describing: tab.id))")
        .accessibilityShowsLargeContentViewer {
            Label(tab.title, systemImage: tab.systemImage)
        }
    }
}
