# Changelog

All notable changes to this project will be documented in this file.

and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-03-28

### Added
- 🛡️ **Database Auto-Recovery**: Implemented a self-healing mechanism that automatically detects persistent startup crashes and resets the local database if a crash loop is detected, eliminating the need for manual cache deletion.

### Fixed
- 🚀 **Full Pagination Sync**: Fully implemented the Memos API v1 pagination protocol (`nextPageToken`). The app now fetches your entire memo collection regardless of size, fixing the previous 100-item limit.
- 🧱 **SwiftData Stability**: Resolved critical `EXC_BREAKPOINT` and unique constraint violation crashes by implementing a "Naked Insertion" and "Clean Room Transfer" strategy for global synchronization.
- 🧪 **Empty Sync Robustness**: Fixed a bug where deleting all memos from the server caused decoding failures and "ghost data" to reappear from the local cache.
- 🧹 **Concurrency Safety**: Refined internal API calls to achieve perfect Swift 6 strict concurrency compliance and removed redundant `await` calls.

---

### 新增
- 🛡️ **数据库自愈机制**: 实现了自动修复机制，能够自动检测持续的启动崩溃。如果检测到崩溃循环，将自动重置本地数据库，用户不再需要手动删除缓存文件。

### 修复
- 🚀 **全量分页同步**: 完整实现了 Memos API v1 的分页协议 (`nextPageToken`)。应用现在可以同步您的全部笔记（无论数量多少），修复了之前仅能获取前 100 条的限制。
- 🧱 **SwiftData 稳定性**: 通过实现“赤裸插入”和“净室迁移”的全局同步策略，解决了导致崩溃的 `EXC_BREAKPOINT` 和唯一性约束冲突问题。
- 🧪 **空数据集同步**: 修复了当服务器端删空所有笔记时，由于解码失败导致本地缓存“借尸还魂”显示旧数据的 Bug。
- 🧹 **并发安全**: 优化了内部 API 调用，实现了 Swift 6 严格并发检查的完全合规，并移除了冗余的 `await` 调用。

## [2.0.4] - 2026-03-28

### Added
- 🔍 **Connectivity Diagnostics**: Added detailed connection error feedback in Sidebar and Settings tooltips.

### Fixed
- 🌐 **Auto URL Normalization**: Resolved "permanent offline" status by automatically adding `http://` or `https://` to server addresses.
- 🔗 **Relation Deduplication**: Fixed an issue where memo references were duplicated many times in offline mode by adding unique constraints to the Relation model.

### Improved
- 🤖 **Automated Connectivity**: The app now automatically detects and reflects server status changes without requiring manual refresh.

---

### 新增
- 🔍 **联网诊断**: 在侧边栏和设置页面的提示中增加了详细的联网错误反馈。

### 修复
- 🌐 **自动 URL 修复**: 通过自动补全服务器地址的 `http://` 或 `https://` 协议头，解决了“持续显示离线”的问题。
- 🔗 **引用去重**: 通过在引用关系模型中增加唯一性约束，修复了离线模式下引用关系重复显示数百次的问题。

### 改进
- 🤖 **自动化联网**: 应用现在能够自动探测并反应服务器状态变化，无需手动点击刷新。

## [2.0.3] - 2026-03-20

### Changed
- 📐 **Adaptive AI Assistant Interface**: The AI Assistant popover now correctly adapts its height based on the content. Short memo previews no longer display excessive empty space, while the interface can still expand appropriately when showing detailed results.

## [2.0.2] - 2026-03-20

### Fixed
- 🖥️ **macOS Sidebar Refinement**: Fixed an issue where the sidebar would automatically collapse after selecting an item. The sidebar now remains visible in the three-column layout as expected on macOS and iPadOS.

## [2.0.1] - 2026-03-20

### Changed
- 🤖 **AI Assistant Interface**: Redesigned the AI Assistant results panel. Clicking on an AI action now pushes a beautifully animated, full-screen, native sub-view instead of a cramped dialog. This ensures comfortable reading for longer summaries or multiple ideas, completely with native text selection and a dedicated copy button.

### Fixed
- 🐛 **AI Context Selection**: Fixed an issue where the AI Assistant popup would incorrectly process the first memo in your timeline rather than the currently selected note. It now perfectly captures context from your active workspace.
- 🌐 **Localization Improvements**: Added missing Chinese localization strings for interface keys ('Key').

## [2.0.0] - 2026-03-19

### Added
- 📱 **Full iOS & iPadOS Support**: Completely redesigned navigation system bringing Essays to iPhone and iPad with native split-view architecture and responsive list columns.
- 🔀 **Native Column Navigation**: Fully standardized the three-column layout to seamlessly transition between sidebar, lists, and note details across macOS, iPadOS, and iOS.

### Fixed
- 🐛 **Navigation Reliability**: Resolved routing issues and crashes (`abort_with_payload`) on iPads when pushing detail views.
- 🔧 **Sidebar Interaction**: Fixed the `NavigationSplitView` on iOS where sidebar items occasionally lost their interactive state by adopting native List-based routing.

## [1.7.0] - 2026-03-19

### Added
- 🏢 **Three-Column Layout**: Upgraded the main navigation to a standard three-column split view (Sidebar, Memo List, and Details). This provides a more professional and efficient browsing experience on macOS.

### Changed
- 🌐 **Enhanced Localization**: Added localized placeholder strings for the new empty detail states in both English and Simplified Chinese.
- 📐 **Optimized View Spacing**: Refined the default widths and constraints for all three columns to ensure optimal readability across different window sizes.

## [1.6.1] - 2026-03-15

### Added
- ⌨️ **Custom Global Shortcut**: Replaced the legacy fixed shortcut picker with a new interactive key recorder! You can now assign any combination of modifier keys to trigger the Quick Input Panel globally.

### Changed
- ⚙️ **Modernized Input Pipeline**: Completely rewrote the global hotkey engine. Dropped 32-bit legacy Carbon APIs in favor of modern AppKit `NSEvent` monitors, achieving perfect Swift 6 strict concurrency safety.

## [1.6.0] - 2026-03-15

### Added
- 🖼️ **Attachments Gallery**: Introducing a dedicated "Attachments" view in the sidebar to browse all image memos in a beautiful grid layout.
- 🎨 **Enhanced Localization**: Comprehensive audit and 100% removal of hardcoded strings across Settings, Timeline, Detail views, and AI Assistant.

### Changed
- 🧹 **Project Cleanup**: Streamlined the project structure by removing unused legacy directories and build logs.
- 📌 **Sidebar Navigation**: Improved the responsiveness of sidebar filters and navigation states.

### Fixed
- 🏷️ **Tag Display Logic**: Resolved an issue where tags were displayed redundantly in the memo detail view.
- 🛠️ **Gallery State Handling**: Fixed a bug where the gallery mode could be unintentionally reset by other sidebar filters.

## [1.5.0] - 2026-03-15

### Added
- 🔍 **Native Quick Look**: Tapping on image attachments now opens the macOS native Quick Look preview.
- 🗺️ **Location Map Preview**: Tapping on location tags now reveals an interactive MapKit "bubble" (popover) centered on the coordinates.

### Changed
- 📋 **Enabling Text Selection**: Memo text content is now fully selectable and copyable, facilitating easier data reuse.
- 🖱️ **Timeline Interaction**: Refined the timeline experience by disabling tap-to-edit on memo cards; the Edit function is now neatly tucked into the card's context menu (`...`).

### Fixed
- 🖼️ **Quick Look Image Recognition**: Resolved a cache issue where macOS misidentified image files as disk images by ensuring standard file extensions are preserved in the local cache.

## [1.3.1] - 2026-03-09

### Fixed
- Fixed settings button not responding in sidebar and menu bar.
- Finalized all localizations for English and Simplified Chinese.

## [1.3.0] - 2026-03-09

### Added
- ⚡ **Global Quick Input**: Instantly capture thoughts from anywhere using the new global shortcut (`Cmd + Option + N`).
- 📌 **System Menu Bar Integration**: A new menu bar icon allows you to quickly open the input panel (left-click) or manage settings/quit the app (right-click).

### Changed
- 🎨 **Light Mode UI Enhancements**: Refined the Liquid Glass theme for light mode, replacing harsh grays with more natural, context-aware backgrounds that blend seamlessly with macOS.
- 🌐 **Localization Extensions**: Added comprehensive Simplified Chinese localization for the new quick input features and restored missing settings components.

### Fixed
- 📅 **Calendar Timeline Bug**: Resolved an issue where jumping to specific dates via the calendar caused the timeline to become blank due to timezone discrepancies.
- 🔍 **Search Engine Enhancements**: Fixed a bug that prevented searching for projects containing specific keyword syntax.

## [1.2.0] - 2026-03-02

### Added
- 🏷️ **Tag Integration**: In-text `#tags` are now automatically parsed upon save, seamlessly updating the sidebar filter list without requiring manual syntax.
- 🚧 **Workspace Support**: Added "Workspace" filter to the sidebar to better align with the new visibility features of the Memos platform.
- 🌍 **Full Localization Completion**: Completed remaining translations for all UI interactables, tooltips, network status, user guest logic and setting components in Simplified Chinese.

### Fixed
- 🏷️ **Sidebar Tags Display**: Fixed an issue where the sidebar tag filter list was empty. The app now locally aggregates and computes all available tags directly from your Memos, restoring navigation by tags after the upstream removal of the `/tags` API endpoint.
- 💥 **Crash Fix (SwiftData)**: Eradicated a critical application crash (`NSMergePolicy`) caused by an inverse relationship mapping conflict when merging multi-relational network data (attachments, locations, relations) into the local `SwiftData` context.
- � **Crash Fix (SwiftUI/AttributeGraph)**: Resolved an `AG::precondition_failure` during timeline rendering by providing stable data-driven identifiers for `Relation` and `Location` models, preventing `ForEach` from losing track of objects over SwiftData context saves.
- �📭 **Empty Timeline Issue**: Rewrote the API deserialization layer to deploy a highly flexible `RelationData` decoder (supporting both structural nested objects and string ID arrays) alongside a resilient Date decoder that mitigates API variances of Fractional Seconds, flawlessly recovering the dashboard timeline.
- 🐛 **Build Issues Resolved**: Cleared scope and constraint mismatches occurring with model entity updates during compilation.

## [1.1.1] - 2026-03-02

### Changed
- 🖋️ **Markdown Engine**: Switched from a custom Regex-based `AttributedString` renderer to a robust AST-based implementation using `mudkipme/MarkdownView`. This provides full GFM support (tables, task lists) and eliminates UI freezes during rendering.
- 📦 **Dependencies**: Integrated `MarkdownView` via SPM and configured via `project.yml`.

## [1.1.0] - 2026-03-02

### Added
- 🌐 **Localization**: Added missing Chinese translations for compose action menu items ("Upload", "Link Memo", "Location").

### Changed
- 🖼️ **Image Loading Engine**: Completely rewrote the image handling pipeline to use a robust local cache and native SwiftUI `AsyncImage`, mimicking the MoeMemos architecture. This eliminates repeated memory crashes (`_CFRelease`, `malloc_default_zone`) and UI layout freezes (`SwiftUI.find1`).
- ⚙️ **Settings UI**: Streamlined preferences by removing the redundant "About" tab.

## [1.0.2] - 2026-02-25
### Added
- 📍 **Location Support**: Automatically record and display geographic location for your memos.
- 🔗 **Memo Linking**: New button in the composer to insert links between memos.

### Fixed
- 🛠️ **Image Upload Fix**: Resolved the "numeric literal" server error by refining the multipart request format.
- 🖼️ **Timeline Previews**: Internal images now correctly appear in the timeline (fixed field mapping and URL construction).

## [1.0.1] - 2026-02-25

## [1.0.0] - 2026-02-25

### Added
- 🤖 **Apple AI Assistant**: On-device text processing using Foundation Models.
- ✨ **Premium UI**: Refined LiquidGlass design with native materials.
- 📅 **Interactive Calendar**: Sidebar integration for daily log filtering.
- 🌍 **Full Localization**: Integrated English and Simplified Chinese support.
- 🕒 **Timeline View**: Chronological grouping of memos.
- 🚀 **Quick Capture**: Top-pinned input box for instant recording.

### Changed
- Refined toolbar buttons to use native macOS styling and materials.
- Improved localization accuracy by resolving 114 String Catalog warnings.

### Fixed
- Fixed Memos API compatibility for v0.26 server versions.
