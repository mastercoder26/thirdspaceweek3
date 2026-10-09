import Charts
import SwiftUI

public struct StatisticsView: View {
    @EnvironmentObject var appState: AppState
    private enum Period: String, CaseIterable {
        case today = "Today"
        case week = "7 days"
        case allTime = "All time"

        var dayCount: Int? {
            switch self {
            case .today: return 1
            case .week: return 7
            case .allTime: return nil
            }
        }
    }

    @State private var period: Period = .week

    private var allNodes: [BrowsingNode] {
        appState.historyStore.getAllNodes()
    }

    private var nodes: [BrowsingNode] {
        let all = allNodes
        guard let dayCount = period.dayCount else { return all }
        let start = Calendar.current.date(
            byAdding: .day, value: -(dayCount - 1), to: Calendar.current.startOfDay(for: Date()))!
        return all.filter { $0.timestampOpened >= start }
    }
    private var domains: [(domain: String, count: Int, duration: TimeInterval)] {
        let grouped = Dictionary(grouping: nodes, by: { $0.domain })
        let results: [(domain: String, count: Int, duration: TimeInterval)] = grouped.map { domain, visits in
            (
                domain: domain, count: visits.count,
                duration: visits.reduce(0.0) { $0 + $1.activeDurationSeconds }
            )
        }
        return results.sorted { $0.count == $1.count ? $0.domain < $1.domain : $0.count > $1.count }
    }
    private var sessionIds: Set<UUID> { Set(nodes.map { $0.sessionId }) }

    private struct ActivityDataPoint: Identifiable {
        var id: Date { date }
        let date: Date
        let count: Int
    }

    private var activityData: [ActivityDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let all = allNodes

        switch period {
        case .today:
            let currentHour = calendar.component(.hour, from: now)
            let hoursToShow = max(currentHour + 1, 12)
            let todayNodes = all.filter { calendar.isDateInToday($0.timestampOpened) }
            return (0..<hoursToShow)
                .map { hour in
                    let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfToday)!
                    let count =
                        todayNodes.filter { calendar.component(.hour, from: $0.timestampOpened) == hour }
                        .count
                    return ActivityDataPoint(date: hourDate, count: count)
                }

        case .week:
            return (0..<7).reversed()
                .map { offset in
                    let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday)!
                    let count = all.filter { calendar.isDate($0.timestampOpened, inSameDayAs: day) }.count
                    return ActivityDataPoint(date: day, count: count)
                }

        case .allTime:
            if all.isEmpty {
                return (0..<7).reversed()
                    .map { offset in
                        let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday)!
                        return ActivityDataPoint(date: day, count: 0)
                    }
            }
            let earliestDate = all.map(\.timestampOpened).min() ?? startOfToday
            let startOfEarliest = calendar.startOfDay(for: earliestDate)
            let daySpan = max(
                1, calendar.dateComponents([.day], from: startOfEarliest, to: startOfToday).day ?? 1)
            let daysToDisplay = max(7, min(30, daySpan + 1))
            return (0..<daysToDisplay).reversed()
                .map { offset in
                    let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday)!
                    let count = all.filter { calendar.isDate($0.timestampOpened, inSameDayAs: day) }.count
                    return ActivityDataPoint(date: day, count: count)
                }
        }
    }

    private var chartTitle: String {
        switch period {
        case .today: return "Pages today"
        case .week: return "Pages this week"
        case .allTime: return "Pages over time"
        }
    }

    private var chartSubtitle: String {
        switch period {
        case .today: return "Today · pages visited by hour"
        case .week: return "Last 7 days · pages visited"
        case .allTime: return "All-time history · pages visited"
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    PageHeading(
                        title: "Browsing activity", subtitle: "Time spent, pages visited, and sites used.")
                    Spacer()
                    Picker("Time period", selection: $period) {
                        ForEach(Period.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 210)
                }
                MetricGrid {
                    MetricCard(
                        title: "Pages visited", value: "\(nodes.count)", detail: "In the selected period",
                        icon: "doc.on.doc")
                    MetricCard(
                        title: "Active time",
                        value: DNAStyle.duration(nodes.reduce(0) { $0 + $1.activeDurationSeconds }),
                        detail: "Recorded page activity", icon: "clock")
                    MetricCard(
                        title: "Sessions", value: "\(sessionIds.count)",
                        detail: "Sessions with page activity", icon: "rectangle.stack")
                    MetricCard(
                        title: "Sites visited", value: "\(domains.count)", detail: "Unique domains visited",
                        icon: "globe")
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(chartTitle).font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text(chartSubtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Chart(activityData) { item in
                        BarMark(
                            x: .value("Time", item.date, unit: period == .today ? .hour : .day),
                            y: .value("Pages", item.count)
                        )
                        .foregroundStyle(DNAStyle.accent)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        if period == .today {
                            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                            }
                        } else if period == .week {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            }
                        } else {
                            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                    }
                    .chartYAxis { AxisMarks(position: .leading) }
                    .frame(height: 160)
                }
                .dnaSurface()
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        domainBreakdown.frame(minWidth: 330)
                        categories.frame(minWidth: 250)
                    }
                    VStack(spacing: 16) {
                        domainBreakdown
                        categories
                    }
                }
            }
            .padding(DNAStyle.pagePadding).frame(maxWidth: DNAStyle.contentWidth).frame(maxWidth: .infinity)
        }
        .background(DNAStyle.background)
    }
    private var domainBreakdown: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Most visited sites").font(.system(size: 16, weight: .semibold))
            if domains.isEmpty {
                Text("Your most visited sites will appear here.").font(.system(size: 12))
                    .foregroundStyle(.secondary).padding(.vertical, 20)
            }
            ForEach(domains.prefix(8), id: \.domain) { item in
                VStack(spacing: 7) {
                    HStack {
                        Text(item.domain).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Spacer()
                        Text(
                            "\(item.count) \(item.count == 1 ? "page" : "pages") · \(DNAStyle.duration(item.duration))"
                        )
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    GeometryReader { geometry in
                        Capsule().fill(DNAStyle.accent.opacity(0.08))
                        Capsule().fill(DNAStyle.accent.opacity(0.75))
                            .frame(
                                width: max(
                                    3,
                                    geometry.size.width * CGFloat(item.count)
                                        / CGFloat(max(1, domains.first?.count ?? 1))))
                    }
                    .frame(height: 5)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).dnaSurface()
    }
    private var categories: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Session categories").font(.system(size: 16, weight: .semibold))
            ForEach(
                SessionCategory.allCases.filter { category in
                    appState.sessions.contains { sessionIds.contains($0.id) && $0.category == category }
                }, id: \.self
            ) { category in
                let count = appState.sessions.filter { sessionIds.contains($0.id) && $0.category == category }
                    .count
                HStack(spacing: 10) {
                    Image(systemName: category.icon).foregroundStyle(category.color).frame(width: 18)
                    Text(category.displayName).font(.system(size: 12))
                    Spacer()
                    Text("\(count)").font(.system(size: 12, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            if sessionIds.isEmpty {
                Text("Categories appear after pages are recorded.").font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Text("Categories are suggested locally from page titles.").font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).dnaSurface()
    }
}
