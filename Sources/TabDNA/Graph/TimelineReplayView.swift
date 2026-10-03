import SwiftUI

struct TimelineReplayView: View {
    @Bindable var replay: SessionReplay

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { replay.seek(to: 0) } label: { Image(systemName: "backward.end.fill") }
                    .help("First page").accessibilityLabel("First page")
                Button { replay.step(-1) } label: { Image(systemName: "backward.frame.fill") }
                    .disabled(replay.pageIDs.isEmpty || replay.index == 0)
                    .help("Previous page").accessibilityLabel("Previous page")
                Button {
                    replay.isPlaying ? replay.pause() : replay.play()
                } label: {
                    Label(replay.isPlaying ? "Pause" : (replay.phase == .finished ? "Replay" : "Play"),
                          systemImage: replay.isPlaying ? "pause.fill" : "play.fill")
                        .frame(minWidth: 65)
                }.buttonStyle(.borderedProminent)
                    .accessibilityLabel(replay.isPlaying ? "Pause playback" : "Play session")
                Button { replay.step(1) } label: { Image(systemName: "forward.frame.fill") }
                    .disabled(replay.pageIDs.isEmpty || replay.index >= replay.pageIDs.count - 1)
                    .help("Next page").accessibilityLabel("Next page")
                Slider(value: Binding(get: { Double(replay.index) }, set: { replay.seek(to: Int($0.rounded())) }),
                       in: 0...Double(max(1, replay.pageIDs.count - 1)), step: 1)
                    .disabled(replay.pageIDs.count < 2)
                    .accessibilityLabel("Page in session")
                    .accessibilityValue("Page \(replay.index + 1) of \(replay.pageIDs.count)")
                Text(replay.isOverview ? "All \(replay.pageIDs.count)" : "\(replay.index + 1) / \(replay.pageIDs.count)")
                    .font(.system(size: 11, weight: .medium)).monospacedDigit()
                    .frame(minWidth: 58, alignment: .trailing)
            }
            HStack(spacing: 12) {
                Toggle("Follow page", isOn: $replay.followsPage).toggleStyle(.checkbox)
                    .help("Keep the current page in view during playback and new visits")
                Picker("Speed", selection: $replay.speed) {
                    Text("Slow").tag(0.5)
                    Text("Normal").tag(1.0)
                    Text("Fast").tag(2.0)
                }.pickerStyle(.segmented).frame(width: 180)
                Spacer()
                Button("Show all pages") { replay.showAll() }
                    .disabled(replay.isOverview)
            }.font(.system(size: 11))
        }.buttonStyle(.borderless)
            .onDisappear { replay.pause() }
    }
}
