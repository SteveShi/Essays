import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), memoCount: 0, recentMemos: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), memoCount: 0, recentMemos: [])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // In a real implementation, fetch data from shared container
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate, memoCount: 0, recentMemos: [])

        // Update every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let memoCount: Int
    let recentMemos: [MemoPreview]
}

struct MemoPreview: Identifiable {
    let id: String
    let content: String
    let createdAt: Date
}

struct EssaysWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
                Spacer()
            }

            Text("Essays")
                .font(.system(size: 16, weight: .bold))

            Spacer()

            HStack {
                Text("\(entry.memoCount)")
                    .font(.system(size: 28, weight: .bold))
                Text("memos")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumWidgetView: View {
    let entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Recent Memos")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text("\(entry.memoCount)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if entry.recentMemos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("No memos yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.recentMemos.prefix(2)) { memo in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memo.content)
                                .font(.system(size: 13))
                                .lineLimit(2)
                            Text(memo.createdAt, style: .relative)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct LargeWidgetView: View {
    let entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Recent Memos")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text("\(entry.memoCount) total")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if entry.recentMemos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No memos yet")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    Text("Open Essays to create your first memo")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.recentMemos.prefix(5)) { memo in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(memo.content)
                                    .font(.system(size: 13))
                                    .lineLimit(3)
                                Text(memo.createdAt, style: .relative)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct EssaysWidget: Widget {
    let kind: String = "EssaysWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            EssaysWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Essays")
        .description("View your recent memos at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    EssaysWidget()
} timeline: {
    SimpleEntry(date: .now, memoCount: 42, recentMemos: [])
}

#Preview(as: .systemMedium) {
    EssaysWidget()
} timeline: {
    SimpleEntry(date: .now, memoCount: 42, recentMemos: [
        MemoPreview(id: "1", content: "This is a sample memo with some content", createdAt: Date().addingTimeInterval(-3600)),
        MemoPreview(id: "2", content: "Another memo example", createdAt: Date().addingTimeInterval(-7200))
    ])
}
