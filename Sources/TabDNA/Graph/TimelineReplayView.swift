import SwiftUI

public struct TimelineReplayView: View {
    @Binding public var currentReplayTime: Date
    @Binding public var followsLatest: Bool
    public let startTime: Date
    public let endTime: Date
    public let totalNodesCount: Int
    public let visibleNodesCount: Int
    @State private var isPlaying = false
    @State private var speed: Double = 1
    @State private var timer: Timer?

    private var duration: TimeInterval { max(1, endTime.timeIntervalSince(startTime)) }
    private var fraction: Double { followsLatest ? 1 : max(0, min(1, currentReplayTime.timeIntervalSince(startTime) / duration)) }

    public var body: some View {
        HStack(spacing: 12) {
            Button {
                pause(); followsLatest = false; currentReplayTime = startTime
            } label: { Image(systemName: "backward.end.fill") }
                .help("Go to first page").accessibilityLabel("Go to first page")
            Button { isPlaying ? pause() : play() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill").frame(width: 24, height: 24)
            }.buttonStyle(.borderedProminent)
                .accessibilityLabel(isPlaying ? "Pause replay" : "Play replay")
            Picker("Replay speed", selection: $speed) {
                ForEach([1.0, 2.0, 5.0, 10.0], id: \.self) { Text("\(Int($0))×").tag($0) }
            }.labelsHidden().frame(width: 55)
            Text(startTime.formatted(.dateTime.hour().minute())).font(.system(size: 10)).foregroundStyle(.secondary)
            Slider(value: Binding(get: { fraction }, set: { value in
                pause(); followsLatest = false
                currentReplayTime = startTime.addingTimeInterval(value * duration)
            }), in: 0...1)
                .accessibilityLabel("Session timeline")
                .accessibilityValue("\(visibleNodesCount) of \(totalNodesCount) pages")
            VStack(alignment: .trailing, spacing: 2) {
                Text(followsLatest ? "All pages" : currentReplayTime.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 11, weight: .medium)).monospacedDigit()
                Text("\(visibleNodesCount) / \(totalNodesCount) pages").font(.system(size: 10)).foregroundStyle(.secondary)
            }.frame(width: 76, alignment: .trailing)
            Button("Latest") {
                pause(); followsLatest = true; currentReplayTime = endTime
            }.help("Show all pages and follow new visits")
        }.buttonStyle(.borderless)
            .onDisappear { pause() }
    }
    private func play() {
        if fraction >= 0.99 { currentReplayTime = startTime }
        followsLatest = false
        isPlaying = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // One pass takes fifteen seconds at 1×, regardless of session length.
            let next = currentReplayTime.addingTimeInterval(duration / 15 * speed * 0.05)
            if next >= endTime { currentReplayTime = endTime; pause() }
            else { currentReplayTime = next }
        }
    }
    private func pause() { timer?.invalidate(); timer = nil; isPlaying = false }
}
