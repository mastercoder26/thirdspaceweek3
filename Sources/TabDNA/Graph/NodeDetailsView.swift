import SwiftUI
import AppKit

public struct NodeDetailsView: View {
    public let node: BrowsingNode
    public let parentNode: BrowsingNode?
    public let childNodes: [BrowsingNode]
    public let onClose: () -> Void
    public let onSelectNode: (UUID) -> Void
    public let onNodeUpdated: ((BrowsingNode) -> Void)?

    @State private var notesText: String
    @State private var isPinned: Bool
    @State private var isCopied: Bool = false

    public init(
        node: BrowsingNode,
        parentNode: BrowsingNode?,
        childNodes: [BrowsingNode],
        onClose: @escaping () -> Void,
        onSelectNode: @escaping (UUID) -> Void,
        onNodeUpdated: ((BrowsingNode) -> Void)? = nil
    ) {
        self.node = node
        self.parentNode = parentNode
        self.childNodes = childNodes
        self.onClose = onClose
        self.onSelectNode = onSelectNode
        self.onNodeUpdated = onNodeUpdated
        _notesText = State(initialValue: node.notes ?? "")
        _isPinned = State(initialValue: node.isPinned)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                FaviconView(domain: node.domain, fallbackEmoji: node.faviconEmoji, size: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.domain)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.secondary)

                    Text("Page details")
                        .font(.system(size: 14, weight: .semibold))
                }

                Spacer()

                // Pin / Bookmark Button
                Button {
                    isPinned.toggle()
                    var updated = node
                    updated.isPinned = isPinned
                    updated.notes = notesText
                    onNodeUpdated?(updated)
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                } label: {
                    Image(systemName: isPinned ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(isPinned ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unstar page" : "Star page")
                .accessibilityLabel(isPinned ? "Unstar page" : "Star page")

                Button {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close page details")
            }
            .padding()
            .background(Color.primary.opacity(0.04))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text(node.title)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(4)

                        Text(node.url)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }

                    // Pivot Point Indicator
                    if childNodes.count >= 2 {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundStyle(Color.purple)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("BRANCHING POINT")
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.purple)
                                Text("This page connects to \(childNodes.count) other pages.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Action Buttons (Open in Browser & Copy)
                    HStack(spacing: 10) {
                        Button {
                            if let url = node.reopenURL {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.right.square.fill")
                                Text("Open in browser")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(node.reopenURL == nil)

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(node.url, forType: .string)
                            isCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                isCopied = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                Text(isCopied ? "Copied!" : "Copy")
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    Divider()

                    // Custom Notes Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.secondary)

                        TextEditor(text: $notesText)
                            .accessibilityLabel("Personal notes")
                            .font(.system(size: 12))
                            .frame(height: 60)
                            .padding(4)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                            .onChange(of: notesText) { _, newText in
                                var updated = node
                                updated.notes = newText
                                updated.isPinned = isPinned
                                onNodeUpdated?(updated)
                            }
                    }

                    Divider()

                    // Metadata Grid
                    VStack(spacing: 12) {
                        detailRow(icon: "clock.fill", title: "Visited At", value: node.formattedTime, color: .blue)
                        detailRow(icon: "hourglass", title: "Active Duration", value: node.formattedDuration, color: .orange)
                        detailRow(icon: "globe", title: "Domain", value: node.domain, color: .purple)
                        detailRow(icon: "macwindow", title: "Recorded Browser", value: node.browserName, color: .teal)
                        detailRow(icon: "arrow.triangle.branch", title: "Branch Level", value: "Level \(node.branchLevel)", color: .cyan)
                        detailRow(icon: "point.3.connected.trianglepath.dotted", title: "Branches Created", value: "\(childNodes.count)", color: .green)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Lineage: Opened From (Parent)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Previous page")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.secondary)

                        if let parent = parentNode {
                            Button {
                                onSelectNode(parent.id)
                            } label: {
                                HStack(spacing: 8) {
                                    FaviconView(domain: parent.domain, fallbackEmoji: parent.faviconEmoji, size: 16)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(parent.title)
                                            .font(.system(size: 12, weight: .medium))
                                            .lineLimit(1)
                                        Text(parent.domain)
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.secondary)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.cyan.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("Starting page in this session")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // Child Branches
                    if !childNodes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Connected pages (\(childNodes.count))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.secondary)

                            ForEach(childNodes) { child in
                                Button {
                                    onSelectNode(child.id)
                                } label: {
                                    HStack(spacing: 8) {
                                        FaviconView(domain: child.domain, fallbackEmoji: child.faviconEmoji, size: 16)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(child.title)
                                                .font(.system(size: 12, weight: .medium))
                                                .lineLimit(1)
                                            Text(child.formattedDuration)
                                                .font(.system(size: 10))
                                                .foregroundStyle(Color.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right.circle")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.purple)
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.purple.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 320)
        .background(DNAStyle.surface)
    }

    private func detailRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
    }
}
