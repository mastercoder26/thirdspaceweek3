import SwiftUI

struct SessionGuideView: View {
    @AppStorage("TabDNA_ShowsSessionGuide") private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            HStack(alignment: .top, spacing: 24) {
                explanation("Pages & lines", icon: "rectangle.on.rectangle", text: "Cards are recorded visits. A line connects a visit to the previous page in that tab, or your last active page. Select a card for details.")
                VStack(alignment: .leading, spacing: 5) {
                    Label("Connections & splits", systemImage: "arrow.triangle.branch").font(.system(size: 11, weight: .semibold))
                    BranchExampleView()
                    Text("A split means two pages share the same starting page.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                explanation("Playback", icon: "play.circle", text: "Play follows visits in order and skips waiting time. It doesn’t recreate every click or tab switch.")
            }.padding(.top, 10).padding(.bottom, 4)
        } label: {
            Label("How to read this session", systemImage: "info.circle")
                .font(.system(size: 12, weight: .semibold))
        }.padding(.horizontal, 18).padding(.vertical, 10)
            .background(DNAStyle.surface)
    }

    private func explanation(_ title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon).font(.system(size: 11, weight: .semibold))
            Text(text).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BranchExampleView: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Page A").padding(.horizontal, 7).padding(.vertical, 4)
                .background(DNAStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
            Image(systemName: "arrow.triangle.branch").foregroundStyle(DNAStyle.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Page B")
                Text("Page C")
            }
        }.font(.system(size: 10, weight: .medium))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page A connects to both page B and page C")
    }
}

struct ReplayContextView: View {
    let sequence: SessionReplaySequence
    let replay: SessionReplay

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: replay.isOverview ? "rectangle.on.rectangle" : "play.rectangle")
                .font(.system(size: 19)).foregroundStyle(DNAStyle.accent)
                .frame(width: 40, height: 40)
                .background(DNAStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                if !replay.isOverview, let page = sequence.page(at: replay.index) {
                    HStack(spacing: 8) {
                        Text(replay.phase == .finished ? "Playback complete" : (replay.isPlaying ? "Now showing" : "Playback paused"))
                            .foregroundStyle(DNAStyle.accent)
                        Text("Page \(replay.index + 1) of \(sequence.pages.count) · \(page.formattedTime)").foregroundStyle(.secondary)
                    }.font(.system(size: 10, weight: .medium))
                    Text(page.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(description(for: page)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                } else {
                    Text("Your session at a glance").font(.system(size: 13, weight: .semibold))
                    Text("\(sequence.pages.count) recorded pages. Press Play to follow the visits, or select any card to explore it.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.horizontal, 18).padding(.vertical, 12)
            .frame(minHeight: 82, alignment: .leading)
            .background(DNAStyle.surface)
            .accessibilityElement(children: .combine)
    }

    private func description(for page: BrowsingNode) -> String {
        let previous = sequence.previousPage(at: replay.index)
        let tabChanged = previous.map { $0.browserName != page.browserName || $0.windowId != page.windowId || $0.tabId != page.tabId } ?? false
        let visit = replay.index == 0 ? "First recorded visit" : (tabChanged ? "Visited in another tab" : "Next recorded visit")
        let source = sequence.connection(to: page).map { " · Connected from \($0.domain)" } ?? " · Starting page"
        return "\(visit) on \(page.domain)\(source)"
    }
}
