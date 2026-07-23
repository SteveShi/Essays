# AGENTS.md - Essays Agent Playbook & Guidelines

This playbook provides definitive guidelines and technical constraints for AI agents working in the `Essays` codebase.

---

## 1. Overview & Core Principles

- **Project Description**: `Essays` is a native multiplatform (macOS 15+ / iOS 17+) SwiftUI client for the self-hosted [Memos](https://usememos.com) note-taking service. Built in Swift 6 with strict concurrency.
- **Author**: Steve Shi / 轩楝 (`com.steveshi.appname` bundle ID naming convention).
- **Default User Communication Language**: Chinese (zh-Hans).
- **Core Architectural Principles**:
  - **Zero Hardcoded Visible Strings**: All user-facing text MUST be localized via `Resources/Localizable.xcstrings`. Use `String(localized: "…", comment: "…")`.
  - **No Entity Proliferation**: Entities, protocols, and interfaces must not be multiplied without necessity. Reuse existing structures wherever possible.
  - **No Legacy Fallbacks**: Target current authoritative API shapes rather than maintaining dual obsolete fallback code paths "just in case".
  - **Minimal Scope**: Keep modifications minimal, self-contained, and tightly focused on the target task.

---

## 2. Workflow & Verification Commands

1. **Inspect Before Modifying**: Read the code and real execution context first. Reuse existing APIs instead of recreating parallel interfaces.
2. **Project Regeneration Guardrail**: If `project.yml` is modified, you MUST run XcodeGen before building:
   ```bash
   xcodegen generate
   ```
3. **Compilation & Test Verification** (Mandatory for code changes):
   - **Build macOS App**:
     ```bash
     xcodebuild -project Essays.xcodeproj -scheme Essays -configuration Debug \
       -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
     ```
   - **Run macOS Test Suite**:
     ```bash
     xcodebuild -project Essays.xcodeproj -scheme Essays -configuration Debug \
       -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test
     ```
     *(To run a single test: append `-only-testing:EssaysTests/<ClassName>/<testMethod>`)*
4. **Artifact Cleanup**: Clean up temporary `*.log` / `*.txt` task artifacts created during execution.

---

## 3. Repository Map & Key Architecture

- **App Entry (`EssaysApp.swift`)**: Sets up `AppState` (environment), `LocalDatabase.shared.container` (SwiftData), `HotkeyManager` (macOS global shortcuts), `UpdaterViewModel` (Sparkle updates), status bar item (`NSStatusItem`), and window frame persistence.
- **State & Data Models (`Models/`)**: SwiftData entities (`Memo`, `Tag`, `User`, `Account`, `Location`, `ServerInfo`), queued mutations (`OutboxTask`), and `AppState`.
- **Database & Sync Engine (`Services/`)**:
  - `Services/LocalDatabase.swift`: SwiftData persistent store, single source of truth for UI.
  - `Services/SyncEngine.swift`: Reconciles queued local mutations (`OutboxTask`) with Memos server state. Handles temporary ID rewrites (`local_…` → `memos/…`) when locally created memos receive server IDs.
- **API Layer (`Services/API/`)**:
  - `MemosAPIV1.swift`: Unified gRPC-gateway REST client for all Memos v0.23+ servers. **Do NOT create separate client files for minor community versions (e.g. v0.31+)**.
  - `MemosAPIDecoder.shared`: Shared JSONDecoder configured for ISO-8601 multi-format date parsing. Must be used for all API date deserialization.
  - `MemosAPIClient.swift`: `@MainActor` API entry point; enforces active account ID validation on concurrent requests to prevent cross-account state leaks.
- **Account & Security (`Services/AccountManager.swift` & `KeychainManager.swift`)**: Secure token storage in Keychain for multi-account management.
- **Shortcuts & Capture (`Services/HotkeyManager.swift` & `Views/QuickInputPanel.swift`)**: macOS global shortcut trigger for floating instant memo capture panel.
- **Update Engine (`Services/UpdaterService.swift`)**: Sparkle 2.x integration (macOS). Feed URL and Ed25519 public key configured in `project.yml`.
- **UI Layer (`Views/`)**: Three-pane `NavigationSplitView` (`SidebarView` → `MemoListView` → `MemoDetailView`) plus `ContentView`, `ComposeMemoView`, `AttachmentsGridView`, `SyncQueueView`, `LoginView`, `Settings/SettingsView`. Cross-platform code gated via `#if os(macOS)`.
- **Theme (`Theme/LiquidGlassTheme.swift`)**: Unified design system tokens and materials.

---

## 4. Build & Release Guardrails

1. **Version Bumps**: Synchronize `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` and regenerate the Xcode project.
2. **Release Notes (`CHANGELOG.md`)**:
   - Follow Sparkle-compatible structure: **English section first, followed by `---`, then Simplified Chinese (`zh-Hans`)**.
3. **CI Pipeline Protection (`.github/workflows/release.yml`)**:
   - **DO NOT MODIFY** the `Extract Version` or `Extract Release Notes` steps in the release workflow.
4. **Sparkle 2.x Signing Pipeline**:
   - Clean private key: `tr -dc A-Za-z0-9+/=`
   - Set `DYLD_FRAMEWORK_PATH` to Sparkle tools directory.
   - Non-interactive stdin signing: `echo "$KEY" | generate_appcast --ed-key-file -`

---

## 5. Definition of Done (DoD)

- Task requirement fulfilled within a clean, tightly scoped diff.
- Code modifications pass macOS build verification (`xcodebuild`).
- Zero hardcoded user-visible strings introduced.
- Workspace clean of temporary log/text files.
- Summary clearly states what was changed, why, and how it was verified.
