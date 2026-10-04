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
                explanation("Playback", icon: "play.circle", text: "Play follows visits in order.")
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
