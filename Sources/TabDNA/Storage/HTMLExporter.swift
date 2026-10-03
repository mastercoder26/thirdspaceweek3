import Foundation
import AppKit

private struct ExportNode: Codable {
    let id: String
    let title: String
    let url: String
    let domain: String
    let emoji: String
    let parentId: String?
    let level: Int
    let duration: String
    let time: String
    let x: Double
    let y: Double
}

private struct ExportEdge: Codable {
    let source: String
    let target: String
    let level: Int
}

@MainActor
public final class HTMLExporter {
    public static let shared = HTMLExporter()

    private init() {}

    public func generateStandaloneHTML(session: BrowsingSession, nodes: [BrowsingNode]) -> String {
        let (layouts, edges) = GraphEngine.shared.computeLayout(nodes: nodes, mode: .horizontal)

        let exportNodes: [ExportNode] = nodes.map { node in
            let layout = layouts[node.id]
            let x = Double(layout?.position.x ?? 100)
            let y = Double(layout?.position.y ?? 100)
            return ExportNode(
                id: node.id.uuidString,
                title: node.title,
                url: node.url,
                domain: node.domain,
                emoji: node.faviconEmoji,
                parentId: node.parentNodeId?.uuidString,
                level: node.branchLevel,
                duration: node.formattedDuration,
                time: node.formattedTime,
                x: x,
                y: y
            )
        }

        let exportEdges: [ExportEdge] = edges.map { edge in
            ExportEdge(
                source: edge.sourceId.uuidString,
                target: edge.targetId.uuidString,
                level: edge.level
            )
        }

        let encoder = JSONEncoder()
        let nodesData = (try? encoder.encode(exportNodes)) ?? Data("[]".utf8)
        let edgesData = (try? encoder.encode(exportEdges)) ?? Data("[]".utf8)
        let nodesJSON = (String(data: nodesData, encoding: .utf8) ?? "[]").replacingOccurrences(of: "<", with: "\\u003c")
        let edgesJSON = String(data: edgesData, encoding: .utf8) ?? "[]"

        let safeTitle = session.displayTitle
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>TabDNA — \(safeTitle)</title>
          <style>
            :root {
              --bg: #18181b;
              --card-bg: #242428;
              --border: rgba(255, 255, 255, 0.12);
              --text: #f0f6fc;
              --subtext: #8b949e;
              --cyan: #4779f5;
              --purple: #ac70dc;
            }
            body, html {
              margin: 0; padding: 0; width: 100%; height: 100%;
              background: var(--bg); color: var(--text);
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
              overflow: hidden; user-select: none;
            }
            #canvas-container {
              width: 100%; height: 100%; position: relative; cursor: grab;
            }
            #canvas-container:active { cursor: grabbing; }
            svg {
              position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none;
            }
            .header-bar {
              position: absolute; top: 16px; left: 16px; z-index: 10;
              background: var(--card-bg); backdrop-filter: blur(12px);
              padding: 12px 18px; border-radius: 12px; border: 1px solid var(--border);
            }
            .header-bar h1 { margin: 0; font-size: 15px; font-weight: 700; }
            .header-bar p { margin: 4px 0 0 0; font-size: 11px; color: var(--subtext); }
            .node {
              position: absolute; width: 200px; height: 76px;
              background: var(--card-bg); backdrop-filter: blur(12px);
              border: 1px solid var(--border); border-radius: 10px;
              padding: 10px; box-sizing: border-box; cursor: pointer;
              transition: border-color 0.15s ease; transform-origin: top left; color: inherit; text-align: left; font-family: inherit;
              box-shadow: 0 4px 16px rgba(0,0,0,0.3);
            }
            .node:hover {
              border-color: var(--cyan);
            }
            .node-header {
              display: flex; align-items: center; gap: 6px; font-size: 11px; color: var(--subtext);
            }
            .node-title {
              margin-top: 4px; font-size: 12px; font-weight: 600;
              white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
            }
            .node-footer {
              display: flex; justify-content: space-between; margin-top: 6px; font-size: 9px; color: var(--subtext);
            }
            .timeline-bar {
              position: absolute; bottom: 20px; left: 50%; transform: translateX(-50%);
              background: var(--card-bg); backdrop-filter: blur(12px);
              padding: 10px 20px; border-radius: 30px; border: 1px solid var(--border);
              display: flex; align-items: center; gap: 12px; z-index: 10; font-size: 12px;
            }
            input[type=range] { accent-color: var(--cyan); width: min(260px, 35vw); }
            .zoom-controls { position: absolute; left: 16px; bottom: 20px; display: flex; gap: 8px; z-index: 20; padding: 10px; background: var(--card-bg); border-radius: 12px; }
            .zoom-controls button { background: transparent; color: var(--text); border: 1px solid var(--border); border-radius: 6px; padding: 4px 9px; cursor: pointer; }
            button:focus-visible, input:focus-visible { outline: 2px solid var(--cyan); outline-offset: 3px; }
            @media (max-width: 700px) { .zoom-controls { bottom: 80px; } .timeline-bar { width: calc(100% - 70px); justify-content: center; } }
            @media (prefers-color-scheme: light) { :root { --bg: #f4f4f6; --card-bg: #fff; --border: #dddde2; --text: #202024; --subtext: #63636c; } }
            @media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
            @media (prefers-reduced-transparency: reduce) { :root { --card-bg: #242428; } }
          </style>
        </head>
        <body>
          <div class="header-bar">
            <h1>\(safeTitle)</h1>
            <p>\(session.pageCount) pages • \(session.branchCount) branches • \(session.formattedDuration)</p>
          </div>

          <div id="canvas-container">
            <svg id="edges-svg"></svg>
            <div id="nodes-container"></div>
          </div>

          <div class="timeline-bar">
            <span>Replay:</span>
            <input aria-label="Session timeline" type="range" id="scrubber" min="1" max="\(max(1, nodes.count))" value="\(nodes.count)">
            <span id="page-count-badge">\(nodes.count)/\(nodes.count)</span>
          </div>

          <div class="zoom-controls">
            <button id="zoom-out" aria-label="Zoom out">−</button>
            <span id="zoom-label">100%</span>
            <button id="zoom-in" aria-label="Zoom in">+</button>
            <button id="fit">Fit</button>
          </div>
          <script>
            const nodes = \(nodesJSON);
            const edges = \(edgesJSON);

            const nodesContainer = document.getElementById('nodes-container');
            const svg = document.getElementById('edges-svg');
            const scrubber = document.getElementById('scrubber');
            const badge = document.getElementById('page-count-badge');

            let scale = 0.9;
            let panX = 40;
            let panY = 40;
            let isDragging = false;
            let startX, startY;

            function render() {
              document.getElementById('zoom-label').textContent = `${Math.round(scale * 100)}%`;
              nodesContainer.innerHTML = '';
              svg.innerHTML = '';
              const limit = parseInt(scrubber.value);
              const visible = nodes.slice(0, limit);
              const visibleIds = new Set(visible.map(n => n.id));
              badge.textContent = `${limit}/${nodes.length}`;

              // Render Edges
              edges.forEach(e => {
                if (visibleIds.has(e.source) && visibleIds.has(e.target)) {
                  const s = nodes.find(n => n.id === e.source);
                  const t = nodes.find(n => n.id === e.target);
                  if (s && t) {
                    const x1 = (s.x + 100) * scale + panX;
                    const y1 = s.y * scale + panY;
                    const x2 = (t.x - 100) * scale + panX;
                    const y2 = t.y * scale + panY;
                    const dx = Math.max(30, (x2 - x1) * 0.5);

                    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
                    path.setAttribute('d', `M ${x1} ${y1} C ${x1 + dx} ${y1}, ${x2 - dx} ${y2}, ${x2} ${y2}`);
                    path.setAttribute('stroke', '#4779f5');
                    path.setAttribute('stroke-width', '2');
                    path.setAttribute('fill', 'none');
                    path.setAttribute('stroke-opacity', '0.6');
                    svg.appendChild(path);
                  }
                }
              });

              // Render Nodes
              visible.forEach(n => {
                const el = document.createElement('button');
                el.type = 'button';
                el.setAttribute('aria-label', `${n.title}, ${n.domain}`);
                el.className = 'node';
                el.style.left = `${(n.x - 100) * scale + panX}px`;
                el.style.top = `${(n.y - 38) * scale + panY}px`;
                el.style.transform = `scale(${scale})`;
                const header = document.createElement('div');
                header.className = 'node-header';
                const emojiSpan = document.createElement('span');
                emojiSpan.textContent = '◉';
                const domainSpan = document.createElement('span');
                domainSpan.style.fontWeight = '600';
                domainSpan.textContent = n.domain;
                const durationSpan = document.createElement('span');
                durationSpan.style.marginLeft = 'auto';
                durationSpan.textContent = n.duration;
                header.appendChild(emojiSpan);
                header.appendChild(domainSpan);
                header.appendChild(durationSpan);

                const titleDiv = document.createElement('div');
                titleDiv.className = 'node-title';
                titleDiv.textContent = n.title;
                titleDiv.title = n.title;

                const footer = document.createElement('div');
                footer.className = 'node-footer';
                const timeSpan = document.createElement('span');
                timeSpan.textContent = n.time;
                const levelSpan = document.createElement('span');
                levelSpan.textContent = n.level === 0 ? 'Starting page' : `Step ${n.level}`;
                footer.appendChild(timeSpan);
                footer.appendChild(levelSpan);

                el.appendChild(header);
                el.appendChild(titleDiv);
                el.appendChild(footer);

                el.onclick = () => { if (/^https?:\\/\\//i.test(n.url)) window.open(n.url, '_blank', 'noopener,noreferrer'); };
                nodesContainer.appendChild(el);
              });
            }

            // Pointer capture keeps dragging continuous when leaving the canvas.
            const canvas = document.getElementById('canvas-container');
            canvas.addEventListener('pointerdown', e => {
              if (e.target.closest('.node')) return;
              canvas.setPointerCapture(e.pointerId);
              isDragging = true; startX = e.clientX - panX; startY = e.clientY - panY;
            });
            canvas.addEventListener('pointermove', e => {
              if (!isDragging) return;
              panX = e.clientX - startX; panY = e.clientY - startY; render();
            });
            canvas.addEventListener('pointerup', () => isDragging = false);
            canvas.addEventListener('pointercancel', () => isDragging = false);
            function zoom(next, x = innerWidth / 2, y = innerHeight / 2) {
              next = Math.max(0.002, Math.min(2.5, next));
              const ratio = next / scale;
              panX = x - (x - panX) * ratio; panY = y - (y - panY) * ratio;
              scale = next; render();
            }
            canvas.addEventListener('wheel', e => {
              e.preventDefault(); zoom(scale * Math.exp(-e.deltaY * 0.002), e.clientX, e.clientY);
            }, { passive: false });
            function fit() {
              if (!nodes.length) return;
              const minX = Math.min(...nodes.map(n => n.x)) - 100;
              const maxX = Math.max(...nodes.map(n => n.x)) + 100;
              const minY = Math.min(...nodes.map(n => n.y)) - 38;
              const maxY = Math.max(...nodes.map(n => n.y)) + 38;
              scale = Math.min(1, (innerWidth - 80) / (maxX - minX), (innerHeight - 220) / (maxY - minY));
              panX = innerWidth / 2 - (minX + maxX) / 2 * scale;
              panY = innerHeight / 2 - (minY + maxY) / 2 * scale;
              render();
            }
            document.getElementById('zoom-out').onclick = () => zoom(scale / 1.25);
            document.getElementById('zoom-in').onclick = () => zoom(scale * 1.25);
            document.getElementById('fit').onclick = fit;

            scrubber.oninput = render;
            fit();
          </script>
        </body>
        </html>
        """
    }

    func saveHTML(session: BrowsingSession, nodes: [BrowsingNode]) -> ExportResult {
        SessionExport.save(session: session, fileExtension: "html", type: .html) {
            Data(generateStandaloneHTML(session: session, nodes: nodes).utf8)
        }
    }
}
