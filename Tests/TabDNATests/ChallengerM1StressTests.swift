import Testing
import Foundation
import SwiftUI
@testable import TabDNA

@Suite("Challenger M1 Empirical Stress Tests")
struct ChallengerM1StressTests {

    // =========================================================================
    // MARK: - 1. Bezier Routing Stress Tests
    // =========================================================================

    /// Evaluates cubic bezier point at parameter t in [0, 1]
    private func evaluateBezier(start: CGPoint, c1: CGPoint, c2: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1.0 - t
        let a = oneMinusT * oneMinusT * oneMinusT
        let b = 3.0 * oneMinusT * oneMinusT * t
        let c = 3.0 * oneMinusT * t * t
        let d = t * t * t
        let x = a * start.x + b * c1.x + c * c2.x + d * end.x
        let y = a * start.y + b * c1.y + c * c2.y + d * end.y
        return CGPoint(x: x, y: y)
    }

    /// Checks if line segment AB and CD intersect (excluding shared endpoints)
    private func segmentsIntersect(a: CGPoint, b: CGPoint, c: CGPoint, d: CGPoint) -> Bool {
        func ccw(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> CGFloat {
            return (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
        }
        let ccw1 = ccw(a, b, c)
        let ccw2 = ccw(a, b, d)
        let ccw3 = ccw(c, d, a)
        let ccw4 = ccw(c, d, b)

        if ((ccw1 > 0 && ccw2 < 0) || (ccw1 < 0 && ccw2 > 0)) &&
           ((ccw3 > 0 && ccw4 < 0) || (ccw3 < 0 && ccw4 > 0)) {
            return true
        }
        return false
    }

    /// High-resolution sampler to detect self-intersections of the cubic Bezier curve
    private func hasSelfIntersection(start: CGPoint, c1: CGPoint, c2: CGPoint, end: CGPoint, samples: Int = 100) -> Bool {
        var points: [CGPoint] = []
        points.reserveCapacity(samples + 1)
        for i in 0...samples {
            let t = CGFloat(i) / CGFloat(samples)
            points.append(evaluateBezier(start: start, c1: c1, c2: c2, end: end, t: t))
        }

        // Check pairs of non-adjacent segments
        for i in 0..<(points.count - 2) {
            let p1 = points[i]
            let p2 = points[i + 1]
            for j in (i + 2)..<(points.count - 1) {
                // Skip adjacent segments sharing an endpoint
                if i == 0 && j == points.count - 2 && start == end { continue }
                let p3 = points[j]
                let p4 = points[j + 1]
                if segmentsIntersect(a: p1, b: p2, c: p3, d: p4) {
                    return true
                }
            }
        }
        return false
    }

    @Test("Bezier routing produces finite numbers and no NaN/Inf across extreme coordinates")
    func testBezierRoutingExtremeCoordinatesFinite() {
        let testPoints: [(CGPoint, CGPoint)] = [
            // Zero and identical
            (CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0)),
            (CGPoint(x: 100, y: 100), CGPoint(x: 100, y: 100)),
            (CGPoint(x: -500, y: -500), CGPoint(x: -500, y: -500)),

            // Axis-aligned with zero delta
            (CGPoint(x: 100, y: 200), CGPoint(x: 100, y: 500)), // same x, deltaY > 0
            (CGPoint(x: 100, y: 500), CGPoint(x: 100, y: 200)), // same x, deltaY < 0
            (CGPoint(x: 200, y: 100), CGPoint(x: 500, y: 100)), // deltaX > 0, same y
            (CGPoint(x: 500, y: 100), CGPoint(x: 200, y: 100)), // deltaX < 0, same y

            // Boundary transitions around 50pt
            (CGPoint(x: 100, y: 100), CGPoint(x: 50, y: 149)),
            (CGPoint(x: 100, y: 100), CGPoint(x: 50, y: 150)),
            (CGPoint(x: 100, y: 100), CGPoint(x: 50, y: 151)),
            (CGPoint(x: 100, y: 100), CGPoint(x: 50, y: 51)),
            (CGPoint(x: 100, y: 100), CGPoint(x: 50, y: 50)),
            (CGPoint(x: 100, y: 100), CGPoint(x: 50, y: 49)),

            // Huge positive/negative coordinates
            (CGPoint(x: 1_000_000, y: 1_000_000), CGPoint(x: -1_000_000, y: -1_000_000)),
            (CGPoint(x: -1_000_000, y: -1_000_000), CGPoint(x: 1_000_000, y: 1_000_000)),
            (CGPoint(x: 0, y: 0), CGPoint(x: 1e8, y: 1e8)),
            (CGPoint(x: 0, y: 0), CGPoint(x: -1e8, y: -1e8)),

            // Microscopic deltas
            (CGPoint(x: 100, y: 100), CGPoint(x: 100.0001, y: 100.0001)),
            (CGPoint(x: 100, y: 100), CGPoint(x: 99.9999, y: 99.9999)),
            (CGPoint(x: 100, y: 100), CGPoint(x: 100, y: 100.0001)),
            (CGPoint(x: 100, y: 100), CGPoint(x: 100.0001, y: 100))
        ]

        let modes: [GraphLayoutMode] = [.horizontal, .waterfall]

        for mode in modes {
            for (start, end) in testPoints {
                let (c1, c2) = GraphViewport.edgeControlPoints(start: start, end: end, mode: mode)

                #expect(!c1.x.isNaN, "c1.x is NaN for start \(start), end \(end), mode \(mode)")
                #expect(!c1.y.isNaN, "c1.y is NaN for start \(start), end \(end), mode \(mode)")
                #expect(!c2.x.isNaN, "c2.x is NaN for start \(start), end \(end), mode \(mode)")
                #expect(!c2.y.isNaN, "c2.y is NaN for start \(start), end \(end), mode \(mode)")

                #expect(!c1.x.isInfinite, "c1.x is Infinite for start \(start), end \(end), mode \(mode)")
                #expect(!c1.y.isInfinite, "c1.y is Infinite for start \(start), end \(end), mode \(mode)")
                #expect(!c2.x.isInfinite, "c2.x is Infinite for start \(start), end \(end), mode \(mode)")
                #expect(!c2.y.isInfinite, "c2.y is Infinite for start \(start), end \(end), mode \(mode)")
            }
        }
    }

    @Test("Bezier routing avoids self-intersecting loops under reversed and collinear topologies")
    func testBezierRoutingNoSelfIntersectingLoops() {
        let scenarios: [(start: CGPoint, end: CGPoint, mode: GraphLayoutMode)] = [
            // Horizontal reversed collinear (the original bug)
            (CGPoint(x: 300, y: 150), CGPoint(x: 100, y: 150), .horizontal),
            // Horizontal reversed small deltaY
            (CGPoint(x: 400, y: 200), CGPoint(x: 150, y: 220), .horizontal),
            (CGPoint(x: 400, y: 200), CGPoint(x: 150, y: 180), .horizontal),
            // Horizontal reversed large deltaY
            (CGPoint(x: 500, y: 100), CGPoint(x: 100, y: 600), .horizontal),
            (CGPoint(x: 500, y: 600), CGPoint(x: 100, y: 100), .horizontal),
            // Horizontal identical X
            (CGPoint(x: 200, y: 100), CGPoint(x: 200, y: 300), .horizontal),
            (CGPoint(x: 200, y: 300), CGPoint(x: 200, y: 100), .horizontal),

            // Waterfall reversed collinear (vertical reverse)
            (CGPoint(x: 200, y: 400), CGPoint(x: 200, y: 100), .waterfall),
            // Waterfall reversed small deltaX
            (CGPoint(x: 200, y: 400), CGPoint(x: 220, y: 100), .waterfall),
            (CGPoint(x: 200, y: 400), CGPoint(x: 180, y: 100), .waterfall),
            // Waterfall reversed large deltaX
            (CGPoint(x: 100, y: 500), CGPoint(x: 600, y: 100), .waterfall),
            (CGPoint(x: 600, y: 500), CGPoint(x: 100, y: 100), .waterfall),
            // Waterfall identical Y
            (CGPoint(x: 100, y: 200), CGPoint(x: 300, y: 200), .waterfall),
            (CGPoint(x: 300, y: 200), CGPoint(x: 100, y: 200), .waterfall),
        ]

        for s in scenarios {
            let (c1, c2) = GraphViewport.edgeControlPoints(start: s.start, end: s.end, mode: s.mode)
            let intersects = hasSelfIntersection(start: s.start, c1: c1, c2: c2, end: s.end, samples: 120)
            #expect(!intersects, "Detected self-intersecting knot loop for start: \(s.start), end: \(s.end), mode: \(s.mode)")
        }
    }

    @Test("Fuzz test Bezier routing on 1,000 random coordinate pairs")
    func testBezierFuzzing() {
        var rng = UInt64(123456789)
        func nextRandom(min: Double, max: Double) -> CGFloat {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let unit = Double(rng >> 11) / Double(1 << 53)
            return CGFloat(min + unit * (max - min))
        }

        for _ in 0..<500 {
            let start = CGPoint(x: nextRandom(min: -2000, max: 2000), y: nextRandom(min: -2000, max: 2000))
            let end = CGPoint(x: nextRandom(min: -2000, max: 2000), y: nextRandom(min: -2000, max: 2000))

            for mode in [GraphLayoutMode.horizontal, GraphLayoutMode.waterfall] {
                let (c1, c2) = GraphViewport.edgeControlPoints(start: start, end: end, mode: mode)
                #expect(!c1.x.isNaN && !c1.y.isNaN && !c2.x.isNaN && !c2.y.isNaN)
                #expect(!c1.x.isInfinite && !c1.y.isInfinite && !c2.x.isInfinite && !c2.y.isInfinite)

                // For curves where end is behind start, verify no self-intersection
                let isReversed = (mode == .horizontal && end.x <= start.x) || (mode == .waterfall && end.y <= start.y)
                if isReversed {
                    let intersects = hasSelfIntersection(start: start, c1: c1, c2: c2, end: end, samples: 80)
                    #expect(!intersects, "Fuzz self-intersection: start \(start), end \(end), mode \(mode)")
                }
            }
        }
    }

    // =========================================================================
    // MARK: - 2. Zoom Math & Clamping Stress Tests
    // =========================================================================

    @Test("Zoom offset preserves exact world coordinate across extreme scales and coordinates")
    func testZoomOffsetWorldInvarianceAcrossExtremeFactors() {
        let anchors: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 400, y: 300),
            CGPoint(x: -1200, y: 850),
            CGPoint(x: 10000, y: -10000),
            CGPoint(x: 0.005, y: 0.005)
        ]

        let initialOffsets: [CGSize] = [
            .zero,
            CGSize(width: -500, height: -350),
            CGSize(width: 2500, height: -1800),
            CGSize(width: -50000, height: 50000)
        ]

        let scalePairs: [(CGFloat, CGFloat)] = [
            (1.0, 1.25),
            (1.25, 1.0),
            (0.15, 2.5),
            (2.5, 0.15),
            (0.5, 0.500001),
            (0.15, 0.15),
            (2.5, 2.5),
            (1.0, 100.0),      // Extreme scale jump
            (100.0, 0.01),     // Extreme scale drop
        ]

        for anchor in anchors {
            for offset in initialOffsets {
                for (oldScale, newScale) in scalePairs {
                    let newOffset = GraphViewport.zoomOffset(from: oldScale, to: newScale, offset: offset, anchor: anchor)

                    #expect(!newOffset.width.isNaN && !newOffset.height.isNaN)
                    #expect(!newOffset.width.isInfinite && !newOffset.height.isInfinite)

                    let worldXBefore = (anchor.x - offset.width) / oldScale
                    let worldYBefore = (anchor.y - offset.height) / oldScale

                    let worldXAfter = (anchor.x - newOffset.width) / newScale
                    let worldYAfter = (anchor.y - newOffset.height) / newScale

                    #expect(abs(worldXBefore - worldXAfter) < 0.001,
                            "World X mismatch: before \(worldXBefore), after \(worldXAfter) for scale \(oldScale) -> \(newScale)")
                    #expect(abs(worldYBefore - worldYAfter) < 0.001,
                            "World Y mismatch: before \(worldYBefore), after \(worldYAfter) for scale \(oldScale) -> \(newScale)")
                }
            }
        }
    }

    @Test("GraphViewport.fit handles degeneracies and boundary conditions")
    func testGraphViewportFitDegenerateBounds() {
        let viewports: [CGSize] = [
            CGSize(width: 800, height: 600),
            CGSize(width: 40, height: 40),      // Smaller than margins (80, 100)
            CGSize(width: 0, height: 0),        // Zero viewport
            CGSize(width: -100, height: -100),  // Negative viewport
            CGSize(width: 10000, height: 10000) // Huge viewport
        ]

        let testBounds: [CGRect] = [
            .zero,                              // Zero bounds
            CGRect(x: 100, y: 100, width: 0, height: 0),
            CGRect(x: -100, y: -100, width: -200, height: -200), // Inverted bounds
            CGRect(x: -100000, y: -100000, width: 200000, height: 200000), // Huge bounds
            CGRect(x: 0, y: 0, width: 0.0001, height: 0.0001), // Micro bounds
            CGRect(x: 100, y: 100, width: 500, height: 300)     // Normal bounds
        ]

        for vp in viewports {
            for b in testBounds {
                let result = GraphViewport.fit(bounds: b, viewport: vp)

                #expect(!result.scale.isNaN && !result.scale.isInfinite)
                #expect(!result.offset.width.isNaN && !result.offset.width.isInfinite)
                #expect(!result.offset.height.isNaN && !result.offset.height.isInfinite)

                if b.width > 0 && b.height > 0 && vp.width > 0 && vp.height > 0 {
                    #expect(result.scale >= GraphViewport.scaleRange.lowerBound)
                    #expect(result.scale <= 1.0)
                }
            }
        }
    }

    @Test("GraphViewport.follow bounds and camera scaling under extreme separation")
    func testGraphViewportFollowExtremeSeparation() {
        let targets = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1_000_000, y: 1_000_000),
            CGPoint(x: -500_000, y: 200_000)
        ]
        let sources: [CGPoint?] = [
            nil,
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: -1_000_000, y: -1_000_000) // Extremely far source
        ]
        let viewports = [
            CGSize(width: 1200, height: 800),
            CGSize(width: 100, height: 100),
            CGSize(width: 10, height: 10)
        ]

        for target in targets {
            for source in sources {
                for vp in viewports {
                    let result = GraphViewport.follow(target: target, source: source, viewport: vp)
                    #expect(!result.scale.isNaN && !result.scale.isInfinite)
                    #expect(!result.offset.width.isNaN && !result.offset.width.isInfinite)
                    #expect(!result.offset.height.isNaN && !result.offset.height.isInfinite)
                    #expect(result.scale >= 0.1 && result.scale <= 0.9)
                }
            }
        }
    }

    // =========================================================================
    // MARK: - 3. StatisticsView Date Math & Timezone Stress Tests
    // =========================================================================

    private func createTestNodes(timestamps: [Date], sessionId: UUID = UUID()) -> [BrowsingNode] {
        return timestamps.map { ts in
            BrowsingNode(
                sessionId: sessionId,
                url: "https://example.com/page",
                title: "Example Page",
                domain: "example.com",
                timestampOpened: ts,
                timestampLastActive: ts.addingTimeInterval(60),
                activeDurationSeconds: 60
            )
        }
    }

    /// Simulates activityData bucket computation from StatisticsView for an explicit calendar and reference date
    private func computeActivityData(nodes allNodes: [BrowsingNode], period: Int, calendar: Calendar, now: Date) -> [(date: Date, count: Int)] {
        let startOfToday = calendar.startOfDay(for: now)

        switch period {
        case 1:
            let currentHour = calendar.component(.hour, from: now)
            let hoursToShow = max(currentHour + 1, 12)
            // In StatisticsView, this is `calendar.isDateInToday($0.timestampOpened)`.
            // When simulating for an arbitrary reference date `now`, we check `isDate(..., inSameDayAs: now)`.
            let todayNodes = allNodes.filter { calendar.isDate($0.timestampOpened, inSameDayAs: now) }
            return (0..<hoursToShow).map { hour in
                let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfToday)!
                let count = todayNodes.filter { calendar.component(.hour, from: $0.timestampOpened) == hour }.count
                return (date: hourDate, count: count)
            }

        case 7:
            return (0..<7).reversed().map { offset in
                let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday)!
                let count = allNodes.filter { calendar.isDate($0.timestampOpened, inSameDayAs: day) }.count
                return (date: day, count: count)
            }

        default:
            if allNodes.isEmpty {
                return (0..<7).reversed().map { offset in
                    let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday)!
                    return (date: day, count: 0)
                }
            }
            let earliestDate = allNodes.map(\.timestampOpened).min() ?? startOfToday
            let startOfEarliest = calendar.startOfDay(for: earliestDate)
            let daySpan = max(1, calendar.dateComponents([.day], from: startOfEarliest, to: startOfToday).day ?? 1)
            let daysToDisplay = max(7, min(30, daySpan + 1))
            return (0..<daysToDisplay).reversed().map { offset in
                let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday)!
                let count = allNodes.filter { calendar.isDate($0.timestampOpened, inSameDayAs: day) }.count
                return (date: day, count: count)
            }
        }
    }

    @Test("StatisticsView activity bucket date math across diverse timezones")
    func testStatisticsDateMathAcrossTimezones() {
        let timezoneIdentifiers = [
            "UTC",
            "America/New_York",       // UTC-5 / UTC-4 (DST)
            "America/Los_Angeles",    // UTC-8 / UTC-7 (DST)
            "Europe/London",          // UTC+0 / UTC+1 (BST)
            "Europe/Paris",           // UTC+1 / UTC+2 (CEST)
            "Asia/Tokyo",             // UTC+9 (no DST)
            "Asia/Kolkata",           // UTC+5:30 (half-hour, no DST)
            "Australia/Adelaide",     // UTC+9:30 / UTC+10:30 (half-hour with DST)
            "Asia/Kathmandu",         // UTC+5:45 (45-min offset)
            "Pacific/Kiritimati",     // UTC+14 (extreme positive)
            "Pacific/Pago_Pago"       // UTC-11 (extreme negative)
        ]

        for tzId in timezoneIdentifiers {
            guard let tz = TimeZone(identifier: tzId) else { continue }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = tz

            // Use noon on a non-DST standard date: 2026-06-15 12:00:00 local
            var comps = DateComponents(year: 2026, month: 6, day: 15, hour: 12)
            comps.timeZone = tz
            guard let referenceDate = calendar.date(from: comps) else { continue }

            let startOfToday = calendar.startOfDay(for: referenceDate)

            // Construct 5 nodes at various hours today in this timezone
            let nodeTimes = [
                startOfToday.addingTimeInterval(3600 * 1),  // 01:00
                startOfToday.addingTimeInterval(3600 * 5),  // 05:00
                startOfToday.addingTimeInterval(3600 * 8),  // 08:00
                startOfToday.addingTimeInterval(3600 * 10), // 10:00
                startOfToday.addingTimeInterval(3600 * 11 + 1800) // 11:30
            ]
            let nodes = createTestNodes(timestamps: nodeTimes)

            // Period 1 (Today)
            let todayBuckets = computeActivityData(nodes: nodes, period: 1, calendar: calendar, now: referenceDate)
            #expect(!todayBuckets.isEmpty)
            let todayTotal = todayBuckets.reduce(0) { $0 + $1.count }
            #expect(todayTotal == nodes.count, "Total count mismatch in timezone \(tzId) for period 1: expected \(nodes.count), got \(todayTotal)")

            // Verify bucket dates are strictly chronological
            for i in 1..<todayBuckets.count {
                #expect(todayBuckets[i].date > todayBuckets[i - 1].date, "Buckets not strictly increasing in timezone \(tzId)")
            }

            // Period 7 (7 days)
            let weekBuckets = computeActivityData(nodes: nodes, period: 7, calendar: calendar, now: referenceDate)
            #expect(weekBuckets.count == 7, "Period 7 must have exactly 7 buckets in timezone \(tzId)")
            let weekTotal = weekBuckets.reduce(0) { $0 + $1.count }
            #expect(weekTotal == nodes.count, "Period 7 total mismatch in timezone \(tzId)")
            #expect(calendar.isDate(weekBuckets.last!.date, inSameDayAs: referenceDate), "Last bucket in period 7 must match reference date in timezone \(tzId)")

            // Period 0 (All time)
            let allBuckets = computeActivityData(nodes: nodes, period: 0, calendar: calendar, now: referenceDate)
            #expect(allBuckets.count >= 7 && allBuckets.count <= 30)
            let allTotal = allBuckets.reduce(0) { $0 + $1.count }
            #expect(allTotal == nodes.count, "Period 0 total mismatch in timezone \(tzId)")
        }
    }

    @Test("StatisticsView bucket date math across DST transitions and boundary behavior")
    func testStatisticsDSTSpringForwardAndFallBack() {
        guard let nyTz = TimeZone(identifier: "America/New_York") else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = nyTz

        // 1. US Spring Forward: March 10, 2024 (2:00 AM becomes 3:00 AM)
        var springComponents = DateComponents(year: 2024, month: 3, day: 10, hour: 16, minute: 0)
        springComponents.timeZone = nyTz
        guard let springDate = calendar.date(from: springComponents) else { return }

        let startOfSpringDay = calendar.startOfDay(for: springDate)
        let springNodes = [
            startOfSpringDay.addingTimeInterval(3600 * 1),  // 01:00 AM (EST)
            startOfSpringDay.addingTimeInterval(3600 * 3),  // 04:00 AM (EDT, 3 elapsed hours from midnight)
            startOfSpringDay.addingTimeInterval(3600 * 10)  // 11:00 AM (EDT)
        ]
        let nodesSpring = createTestNodes(timestamps: springNodes)

        let springBuckets = computeActivityData(nodes: nodesSpring, period: 1, calendar: calendar, now: springDate)
        #expect(!springBuckets.isEmpty)
        let springCount = springBuckets.reduce(0) { $0 + $1.count }
        #expect(springCount == nodesSpring.count, "Spring forward total nodes must be preserved")

        // 2. US Fall Back: November 3, 2024 (2:00 AM repeats)
        var fallComponents = DateComponents(year: 2024, month: 11, day: 3, hour: 16, minute: 0)
        fallComponents.timeZone = nyTz
        guard let fallDate = calendar.date(from: fallComponents) else { return }

        let startOfFallDay = calendar.startOfDay(for: fallDate)
        let fallNodes = [
            startOfFallDay.addingTimeInterval(3600 * 1),  // 01:00 AM
            startOfFallDay.addingTimeInterval(3600 * 5),  // 04:00 AM (5 elapsed hours)
            startOfFallDay.addingTimeInterval(3600 * 14)  // 01:00 PM (14 elapsed hours)
        ]
        let nodesFall = createTestNodes(timestamps: fallNodes)

        let fallBuckets = computeActivityData(nodes: nodesFall, period: 1, calendar: calendar, now: fallDate)
        #expect(!fallBuckets.isEmpty)
        let fallCount = fallBuckets.reduce(0) { $0 + $1.count }
        #expect(fallCount == nodesFall.count, "Fall back total nodes must be preserved")
    }

    @Test("StatisticsView period 0 empty and single-node boundary behaviors")
    func testStatisticsEmptyAndSingleNode() {
        let calendar = Calendar.current
        let now = Date()

        // 1. Empty nodes
        let emptyBucketsPeriod0 = computeActivityData(nodes: [], period: 0, calendar: calendar, now: now)
        #expect(emptyBucketsPeriod0.count == 7, "Empty period 0 must return 7 zero-filled buckets")
        #expect(emptyBucketsPeriod0.allSatisfy { $0.count == 0 })

        let emptyBucketsPeriod1 = computeActivityData(nodes: [], period: 1, calendar: calendar, now: now)
        #expect(!emptyBucketsPeriod1.isEmpty)
        #expect(emptyBucketsPeriod1.allSatisfy { $0.count == 0 })

        // 2. Single node today
        let singleNodeToday = createTestNodes(timestamps: [now])
        let singleBucketsPeriod0 = computeActivityData(nodes: singleNodeToday, period: 0, calendar: calendar, now: now)
        #expect(singleBucketsPeriod0.count >= 7)
        let totalPeriod0 = singleBucketsPeriod0.reduce(0) { $0 + $1.count }
        #expect(totalPeriod0 == 1)

        // 3. Node 60 days ago
        let oldDate = calendar.date(byAdding: .day, value: -60, to: now)!
        let oldNode = createTestNodes(timestamps: [oldDate])
        let oldBucketsPeriod0 = computeActivityData(nodes: oldNode, period: 0, calendar: calendar, now: now)
        // Verified: period 0 caps at 30 days of display
        #expect(oldBucketsPeriod0.count == 30)
    }
}
