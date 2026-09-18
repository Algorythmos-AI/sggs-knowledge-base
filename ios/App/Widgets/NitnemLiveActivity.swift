#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

/// The reading Live Activity (Lock Screen banner + Dynamic Island). Shows the bani title and a
/// whole-percent progress bar only — never a verse. Same paper-and-gold vocabulary as the widgets.
struct NitnemLiveActivity: Widget {
    private var palette: AccentPalette { .brandDefault }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NitnemActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(palette.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.done ? "checkmark.seal.fill" : "book.closed")
                        .foregroundStyle(palette.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(percentText(context.state)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.titleEn).font(WidgetType.serif(15)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress).tint(palette.accent)
                }
            } compactLeading: {
                Image(systemName: "book.closed").foregroundStyle(palette.accent)
            } compactTrailing: {
                Text(percentText(context.state)).font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: context.state.done ? "checkmark" : "book.closed").foregroundStyle(palette.accent)
            }
            .widgetURL(URL(string: "sggs://bani/\(context.attributes.key)"))
        }
    }

    private func percentText(_ s: NitnemActivityAttributes.ContentState) -> String {
        s.done ? "Done" : "\(ReadingActivityPolicy.wholePercent(s.progress))%"
    }

    private func lockScreen(_ context: ActivityViewContext<NitnemActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().strokeBorder(palette.accent.opacity(0.22), lineWidth: 4)
                Circle().trim(from: 0, to: context.state.progress)
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if context.state.done {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(palette.accent)
                }
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("READING").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(palette.accentText)
                Text(context.attributes.titleGm).font(WidgetType.gurmukhi(19)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7)
                if !context.state.sectionLabel.isEmpty {
                    Text(context.state.sectionLabel).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text(percentText(context.state)).font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
#endif
