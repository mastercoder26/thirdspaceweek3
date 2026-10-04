# TabDNA

A native macOS app that turns browsing activity into connected trails. Revisit a session, find a page, and see how one discovery led to another.

## Run

Requires macOS 14 or later and Swift 6 to build.

- Run `sh build_app.sh` to build a release and generate `TabDNA.app`.
- Open the generated `TabDNA.app` to run the application.
- Run `swift run TabDNA` during development.
- Run `swift test` to run the isolated core and usability regression tests.

## Using the app

**Overview** shows today’s activity, a recent trail to continue, and session cards. All daily metrics use pages recorded today; the library contains older sessions too.

**Session library** groups history by date. Search by session title or domain, filter by category, and sort by recency. Click a row to open its graph. Rename sessions from the row’s action menu. Custom names take priority over automatic suggestions. Deletion requires confirmation.

**Saved pages** collects stars and pages with notes across all sessions. Search titles, sites, URLs, or note text; filter to starred pages or notes. Open the original URL or show the page in its session.

**Session map** offers Connections and Timeline layouts. A card represents a recorded visit. Lines connect it to the previous page recorded in that tab, or the last active page. Two branches mean two later visits share the same recorded starting page; this can happen when you return to a page or use another tab. The map includes a visual explanation of splits, and page details explain multiple connections.

Press Play to reveal visits one at a time. The camera smoothly follows the current page, includes its source when both fit, and keeps distant pages readable. Each visit gets 2.4 seconds at Normal speed; Slow and Fast adjust that pace. Waiting time between visits is skipped. The current-page panel shows the title, recorded time, tab change, and source. Playback describes recorded visits rather than recreating every click or tab switch.

Use First page, Previous page, Next page, or the page slider to move through the sequence. Scrubbing pauses playback. Show all pages returns to the full map. Follow page keeps the current visit in view and follows newly recorded pages in an active session. Panning, zooming, repositioning a card, or selecting a page pauses playback and gives you camera control; pressing Play turns following back on.

Drag empty space to pan; pinch or use the zoom buttons to zoom. Fit pages frames the visible visits, and Overview toggles a small map. Select a page for details, notes, stars, and connections. Changing layouts resets card positions while keeping the current playback step. Search a title, site, URL, or note, then press Return or Next to visit a match. Sessions in the toolbar opens the library to choose another session.

**Insights** shows activity for today, the past seven days, or all time, plus a seven-day activity chart and site/category breakdowns.

**Settings & privacy** controls recording, polling interval, inactivity boundaries, excluded domains, optional site-icon downloads, and data export. JSON export opens a save dialog. Clearing history requires confirmation.

### Keyboard and menu bar

- **⌘K:** quick search for commands, sessions, and recorded pages.
- **↑ / ↓:** choose a search result; **Return:** open it; **Escape:** close search.
- **⌘N:** begin a new browsing session.
- **Escape in Session map:** close page details and clear graph search.
- The menu bar offers tracking controls and quick access to the main window.

## Recording and privacy

TabDNA supports Comet, Google Chrome, Safari, Brave, Arc, Microsoft Edge, Opera, Vivaldi, and Chromium through each browser’s AppleScript interface. macOS may ask for Automation permission. If browser access is unavailable, check System Settings → Privacy & Security → Automation.

Only the active tab of a frontmost supported browser is recorded. Background browsers do not accumulate active browsing time. Switching back to a known, unchanged tab reuses its recorded page. Navigation and newly observed tabs are linked using tab identity and the most recently active page. These connections are inferred from observations; TabDNA cannot know the exact link that opened every page.

History, stars, and notes stay in `~/Library/Application Support/TabDNA/tabdna_history.json`. The app skips excluded domains and their subdomains, strips a defined set of sensitive URL query parameters, and does not inspect forms, keystrokes, or page contents. Domain exclusions apply to future visits; they do not remove existing history. Browser titles and URLs can still contain private information, so configure exclusions for sites you do not want recorded. Private/incognito windows are not separately detected.

Suggested names use a real page title, and categories use local domain and title rules. No external AI provider is connected. Tracking pause/resume and preferences persist across launches. Optional site-icon downloads send domain names to Google’s favicon service; this is disabled by default. Local fallbacks and previously cached icons work without downloading icons.

## Export

The Session map toolbar exports PNG, Markdown, and standalone interactive HTML through native save dialogs. Choose the filename and destination, or cancel without creating a file. PNG exports account for graph bounds, including negative coordinates, and cap their longest raster dimension at 8,000 pixels to bound memory. HTML exports include timeline replay, anchored zoom, panning, keyboard-focusable pages, and a Fit control. Page titles are escaped for HTML and embedded script data.

## Design and accessibility

The interface uses system typography, a consistent blue accent, date-based wayfinding, native buttons and sliders, and solid content cards. Translucency is reserved for floating controls. Panels and graph navigation use short, critically damped springs; gesture movement remains direct. Screen transitions use restrained fades. Reduced-motion preferences remove spatial navigation animation and use short fades.

Design references were reviewed through the Mobbin plugin, including [Craft’s canvas](https://mobbin.com/screens/33758096-ed8d-41f9-af6d-e56f1099b90f) and [Fibery’s whiteboard](https://mobbin.com/screens/23014d15-193a-45ae-808e-e8ab2d584c32). The implementation follows the apple-design and SwiftUI patterns skills.

Verification: 38 automated tests pass, including chronological replay, cancellation after pause or scrubbing, live updates, and readable camera framing. Native UI checks covered saved-page and note search, stars, notes, session renaming, keyboard navigation, graph selection, zoom, dragging, layout changes, timeline replay, tracking controls, exclusion validation, persistence across relaunch, deletion cancellation, and PNG/Markdown/HTML/JSON exports. The exported HTML timeline, zoom, and Fit controls were also checked in a browser. UI checks used isolated history and preferences. Live recording was not checked separately in every supported browser.

## Source layout

- `Graph/`: layout engines, viewport math, page cards and details, timeline, overview map, and PNG export.
- `State/`: app selection, live session lifecycle, and local session categorization.
- `Tracking/`: browser adapters and frontmost-tab observation.
- `Storage/`: local history, exclusions, site icons, and Markdown/HTML exports.
- `Tests/TabDNATests/`: model, layout, persistence, privacy, export safety, and viewport regression tests. Tests use temporary history stores and isolated preferences rather than the live user history.
