# Paper

A native macOS plain-text editor built with SwiftUI + AppKit. Fast, focused, and
faithful to the attached design — sidebar, in-window tabs, a line-numbered editor,
status bar, find/replace, a ⌘K command palette, ⌘P quick-open, and a tabbed
Settings window with three visual themes plus a custom accent color.

## Requirements

- macOS 14 or later (looks and runs native on macOS 26).
- Either **full Xcode** or just the **Command Line Tools** — this project builds
  from the terminal with Swift Package Manager; it does not need the Xcode IDE.

## Build & run

```bash
./build.sh release run     # compile, assemble Paper.app, code-sign, launch
./build.sh release         # build the bundle without launching
./build.sh debug           # faster debug build
```

The bundle is written to `build/Paper.app`. You can also `open build/Paper.app`.

Open in Xcode (if installed) for editing: `open Package.swift`.

### Engine self-test

The core (non-UI) engine — encoding detection, EUC-KR round-trips, line-ending
handling, line indexing, fuzzy match — can be verified headlessly:

```bash
swift build -c release && ./.build/release/Paper --selftest
```

### Preview renders (dev)

`./.build/release/Paper --render <dir>` renders each screen/theme to PNG off-screen
(via `ImageRenderer` + `cacheDisplay` for the AppKit editor) — used to verify the UI
without a display. See `Sources/Paper/Support/RenderHarness.swift`.

## Features

- **Plain text only.** Rich text, smart quotes/dashes, and text substitutions are
  all disabled — what you type is exactly what is saved.
- **Native performance.** The editor is an AppKit `NSTextView` (TextKit 1) wrapped
  for SwiftUI, with a custom `NSRulerView` gutter for line numbers (SF Mono). One
  live editor per tab preserves undo history, scroll position, and selection.
- **Tabs** in the titlebar region, collapsible **sidebar** (search, recent files,
  folder shortcuts with counts).
- **Find & replace** bar with match count, case-sensitivity, and regex.
- **⌘K command palette** and **⌘P quick-open**, both fuzzy-searched and keyboard-driven.
- **Themes:** 웜 페이퍼 (light), 쿨 시스템 (light), 다크 그레파이트 (dark), plus
  시스템 자동. A **custom accent color** (swatches or full color picker) overrides
  the theme's accent everywhere — caret, selection, active tab, highlights.
- **Encoding & line endings:** auto-detects UTF-8/BOM, UTF-16, and **EUC-KR**;
  per-document encoding and LF/CRLF/CR are switchable from the status bar.
- **Auto-save** at a configurable interval.

## Keyboard shortcuts

| Action | Shortcut | Action | Shortcut |
|---|---|---|---|
| New document | ⌘N | Command palette | ⌘K |
| Open… | ⌘O | Quick open | ⌘P |
| Save | ⌘S | Find in file | ⌘F |
| Save As… | ⇧⌘S | Toggle sidebar | ⌃⌘S |
| Save all tabs | ⌥⌘S | Next / prev tab | ⇧⌘] / ⇧⌘[ |
| Close tab | ⌘W | Settings | ⌘, |

## Project layout

```
Sources/Paper/
├── PaperApp.swift          @main entry, menu commands, Settings scene
├── Model/                  TextDocument, TextEncoding, LineEnding, AppState, RecentFile
├── Theme/                  PaperColor, Theme (3 presets + custom accent)
├── Settings/               AppSettings (persisted), SettingsView
├── Editor/                 EditorController, PaperTextView, LineNumberRulerView,
│                           LineIndex, PaperEditor (NSViewRepresentable)
├── Views/                  ContentView, TopBar, SidebarView, StatusBarView,
│                           FindBarView, CommandPaletteView, QuickOpenView, ViewSupport
└── Support/                AppearanceObserver, PaperUtil, SelfTest
```

## Notes

- The app currently ships without a custom `.icns`; drop `build/AppIcon.icns` and
  `build.sh` will bundle it.
- The sidebar's recent files and folders are real and persisted; on first launch
  they start empty (the sample meeting-notes text is the initial untitled document).
