import SwiftUI
import Charts

public struct StatisticsView: View {
    @EnvironmentObject var appState: AppState
    @State private var period = 7
    private var nodes: [BrowsingNode] {
        let all = appState.historyStore.getAllNodes()
        guard period != 0 else { return all }
        let start = Calendar.current.date(byAdding: .day, value: -(period - 1), to: Calendar.current.startOfDay(for: Date()))!
        return all.filter { $0.timestampOpened >= start }
    }
    private var domains: [(domain: String, count: Int, duration: TimeInterval)] {
        let grouped = Dictionary(grouping: nodes, by: { $0.domain })
        let results: [(domain: String, count: Int, duration: TimeInterval)] = grouped.map { domain, visits in
            (domain: domain, count: visits.count, duration: visits.reduce(0.0) { $0 + $1.activeDurationSeconds })
        }
        return results.sorted { $0.count == $1.count ? $0.domain < $1.domain : $0.count > $1.count }
    }
    private var sessionIds: Set<UUID> { Set(nodes.map { $0.sessionId }) }
    private var activity: [(day: Date, count: Int)] {
        let calendar = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: Date()))!
            let count = appState.historyStore.getAllNodes().filter { calendar.isDate($0.timestampOpened, inSameDayAs: day) }.count
            return (day, count)
        }
    }
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    PageHeading(title: "Browsing activity", subtitle: "Time spent, pages visited, and sites used.")
                    Spacer()
                    Picker("Time period", selection: $period) {
                        Text("Today").tag(1); Text("7 days").tag(7); Text("All time").tag(0)
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 210)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    MetricCard(title: "Pages visited", value: "\(nodes.count)", detail: "In the selected period", icon: "doc.on.doc")
                    MetricCard(title: "Active time", value: DNAStyle.duration(nodes.reduce(0) { $0 + $1.activeDurationSeconds }), detail: "Recorded page activity", icon: "clock", color: .teal)
                    MetricCard(title: "Sessions explored", value: "\(sessionIds.count)", detail: "Sessions with page activity", icon: "rectangle.stack", color: .purple)
                    MetricCard(title: "Different sites", value: "\(domains.count)", detail: "Unique domains visited", icon: "globe", color: .orange)
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Pages this week").font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text("Last 7 days · pages visited").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Chart(activity, id: \.day) { item in
                        BarMark(x: .value("Day", item.day, unit: .day), y: .value("Pages", item.count))
                            .foregroundStyle(DNAStyle.accent).cornerRadius(4)
                    }.chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.abbreviated)) } }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .frame(height: 160)
                }.dnaSurface()
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        domainBreakdown.frame(minWidth: 330)
                        categories.frame(minWidth: 250)
                    }
                    VStack(spacing: 16) { domainBreakdown; categories }
                }
            }.padding(28).frame(maxWidth: 1280).frame(maxWidth: .infinity)
        }.background(DNAStyle.background)
    }
    private var domainBreakdown: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Where you explored").font(.system(size: 16, weight: .semibold))
            if domains.isEmpty {
                Text("Visit a few pages to see your most explored sites.").font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 20)
            }
            ForEach(domains.prefix(8), id: \.domain) { item in
                VStack(spacing: 7) {
                    HStack {
                        Text(item.domain).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Spacer()
                        Text("\(item.count) \(item.count == 1 ? "page" : "pages") · \(DNAStyle.duration(item.duration))").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    GeometryReader { geometry in
                        Capsule().fill(DNAStyle.accent.opacity(0.08))
                        Capsule().fill(DNAStyle.accent.opacity(0.75))
                            .frame(width: max(3, geometry.size.width * CGFloat(item.count) / CGFloat(max(1, domains.first?.count ?? 1))))
                    }.frame(height: 5)
                }.accessibilityElement(children: .combine)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).dnaSurface()
    }
    private var categories: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("What caught your attention").font(.system(size: 16, weight: .semibold))
            ForEach(SessionCategory.allCases.filter { category in
                appState.sessions.contains { sessionIds.contains($0.id) && $0.category == category }
            }, id: \.self) { category in
                let count = appState.sessions.filter { sessionIds.contains($0.id) && $0.category == category }.count
                HStack(spacing: 10) {
                    Image(systemName: category.icon).foregroundStyle(category.color).frame(width: 18)
                    Text(category.displayName).font(.system(size: 12))
                    Spacer()
                    Text("\(count)").font(.system(size: 12, weight: .medium)).monospacedDigit().foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine)
            }
            if sessionIds.isEmpty {
                Text("Categories appear after pages are recorded.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Text("Categories are suggested locally from page titles.").font(.system(size: 10)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).dnaSurface()
    }
}
