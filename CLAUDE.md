# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Essays is a native multiplatform (macOS 15+ / iOS 17+) SwiftUI client for the self-hosted [Memos](https://usememos.com) note-taking service. Swift 6 with strict concurrency. Default communication language with the user is **Chinese**.

## Build & Project Generation

The Xcode project is generated from `project.yml` via XcodeGen. **After any change to `project.yml`, regenerate before building:**

```bash
xcodegen generate
```

Build the macOS app (the verification command required after code changes):

```bash
xcodebuild -project Essays.xcodeproj -scheme Essays -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Run the test bundle (`EssaysTests`, macOS-only):

```bash
xcodebuild -project Essays.xcodeproj -scheme Essays -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test
```

Single test: append `-only-testing:EssaysTests/<ClassName>/<testMethod>`.

The iOS target (`EssaysiOS`) shares the same sources but uses `Info-iOS.plist` and a separate bundle id.

## Architecture

The app is **offline-first**: every user mutation goes to a local SwiftData store and is reconciled against a Memos server via a background sync engine.

- **`EssaysApp.swift`** — App entry. Sets up `AppState` (environment), `LocalDatabase.shared.container` (SwiftData), `HotkeyManager` (macOS global shortcuts), `MemosAIAssistant` (gated on macOS 26+ Foundation Models), `UpdaterViewModel` (Sparkle), the menu-bar `NSStatusItem`, and `MainWindowAutosaveConfigurator` for window frame persistence. Cross-cutting events use named `Notification.Name`s (`createNewMemo`, `focusSearch`, `toggleSidebar`, `toggleQuickInput`, `databaseContainerDidChange`).
- **`Models/`** — SwiftData entities (`Memo`, `Tag`, `User`, `Account`, `Location`, `ServerInfo`) plus `OutboxTask` (queued local mutations) and `AppState` (UI-facing observable state).
- **`Services/LocalDatabase.swift`** — SwiftData container, the source of truth for the UI. Account switches post `databaseContainerDidChange` so the root view re-mounts with a new container.
- **`Services/SyncEngine.swift`** — Reconciles outbox tasks + server state with the local DB. Handles the temporary-id (`local_…` → `memos/…`) rewrite when locally created memos get their server IDs after first sync (relations and references must be migrated together).
- **`Services/API/`** — Versioned Memos REST client. `MemosAPIProtocol.swift` defines DTOs and the version-agnostic surface; `MemosAPIV026.swift` and `MemosAPIV027.swift` implement per-version differences. `MemosAPIClient.swift` selects the right implementation based on detected server version. **Be conservative with field shapes** — server responses drift between versions; do not add speculative fallbacks.
- **`Services/AccountManager.swift`** — Multi-account credentials (server URL + access token) stored in Keychain.
- **`Services/HotkeyManager.swift`** + **`Views/QuickInputPanel.swift`** — macOS global shortcut → floating Quick Input panel for instant capture.
- **`Services/MemosAIAssistant.swift`** — On-device Foundation Models integration (macOS 26+ only). All AI processing is local; do not add network round-trips here.
- **`Services/UpdaterService.swift`** — Sparkle 2.x integration (macOS only). Ed25519 public key and feed URL live in `project.yml` settings.
- **`Views/`** — Three-pane `NavigationSplitView` (`SidebarView` → `MemoListView` → `MemoDetailView`) plus `ContentView`, `ComposeMemoView`, `AIAssistantView`, `AttachmentsGridView`, `SyncQueueView`, `LoginView`, and `Settings/SettingsView`. iOS and macOS share these files; gate platform-specific code with `#if os(macOS)`.
- **`Resources/Localizable.xcstrings`** — Single source for every user-visible string (English + Simplified Chinese).
- **`Theme/`** — "LiquidGlass" tokens / materials shared across views.

## Hard Rules (from AGENTS.md)

These constraints have caused regressions in the past — follow them strictly:

- **All user-visible text must go through `Resources/Localizable.xcstrings`.** No hardcoded strings in views or services. Use `String(localized: "…", comment: "…")`.
- **No legacy fallbacks.** When server API shapes change, target the current real response; don't keep dual code paths "just in case".
- **Don't multiply entities unnecessarily.** Reuse existing API/types instead of adding parallel ones.
- **Keep changes scoped.** No drive-by refactors; touch only files relevant to the task.
- **Bundle id format:** `com.steveshi.appname` style (current ids: `com.essays.app`, `com.essays.app.ios`, `com.essays.app.tests`).
- Clean up any temporary `*.log` / `*.txt` artifacts created during a task before finishing.

## Release Pipeline

Releases are driven by `CHANGELOG.md` pushes to `main` (see `.github/workflows/release.yml`). When bumping a version:

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`, then run `xcodegen generate`.
2. Add a new `## [x.y.z] - YYYY-MM-DD` section to `CHANGELOG.md` with **English first, then `---`, then Chinese** (Sparkle parses this format).
3. **Do NOT modify** the `Extract Version` or `Extract Release Notes` steps in `.github/workflows/release.yml` — they are verified working.
4. Sparkle 2.x signing chain (already wired in CI, leave intact): private key cleaned via `tr -dc A-Za-z0-9+/=`, `DYLD_FRAMEWORK_PATH` set to Sparkle tools dir, signing via stdin: `echo "$KEY" | generate_appcast --ed-key-file -`.

## Definition of Done

- Requirement met, scope contained.
- macOS build passes with the command above (when code changed).
- No new hardcoded user-facing strings.
- No leftover scratch files.
- Explanation covers what changed, why, and how to verify.
