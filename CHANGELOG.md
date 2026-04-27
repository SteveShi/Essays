# Changelog

All notable changes to this project will be documented in this file.

and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.5.6] - 2026-04-27

### Changed
- 🧹 **Internal Cleanup**: Consolidated duplicate JSON decoder configuration and relation-type parsing across the v0.26/v0.27 API clients into shared helpers, and merged the identical create/update outbox payload types into a single `MemoPayload`. Pure internal refactor — no user-facing behavior change, existing pending sync tasks continue to work.

---

### Chinese

### 修改
- 🧹 **内部清理**：将 v0.26/v0.27 API 客户端中重复的 JSON 解码器配置与关系类型解析逻辑抽取为共享 helper，并合并字段完全一致的 create/update outbox 负载为单一 `MemoPayload`。纯内部重构，行为不变，已存在的待同步任务继续正常工作。

---

## [2.5.5] - 2026-04-27

### Fixed
- 🔗 **Reference and Backlink Consistency**: Centralized local memo reference syncing so edited memos, newly composed memos, timeline quick captures, and Quick Input memos all create and remove reference relations consistently.
- 🔁 **Temporary ID Reference Migration**: Updated local reference relations when pending `local_...` memos are replaced by server `memos/...` IDs after sync.
- ↩️ **Referenced-By Visibility**: Timeline cards now show relation sections for memos that are only referenced by other memos, not just memos with outgoing references.

---

### Chinese

### 修复
- 🔗 **引用与被引用一致性**: 统一本地 Memo 引用关系同步逻辑，编辑、新建、时间线快速捕获与快捷输入都会一致地创建和移除引用关系。
- 🔁 **临时 ID 引用迁移**: 当待同步的 `local_...` Memo 在同步后替换为服务端 `memos/...` ID 时，同步更新本地引用关系。
- ↩️ **被引用可见性**: 时间线卡片现在会显示纯“被引用”的关系区，不再只显示存在出站引用的 Memo。

---

## [2.5.3] - 2026-04-26

### Added
- 🔴 **Quick Input Native Close Button**: Added a macOS native close button in the top-left corner of the Quick Input panel for consistent system behavior.
- 🖱️ **Double-Click to Edit Memo Card**: Added macOS double-click editing on timeline cards to open the existing memo editor directly.

### Fixed
- 🪟 **Main Window Size Persistence**: The main window now uses frame autosave so your manually adjusted size and position are remembered reliably.
- 🎯 **First-Launch Window Defaults**: On first launch (when no saved frame exists), the main window now opens centered at a default size, then fully follows user-resized dimensions afterward.
- 🌗 **Quick Input Theme Adaptation**: Quick Input panel now follows light/dark/system theme correctly instead of being forced to dark HUD style.

---

### Chinese

### 新增
- 🔴 **快捷输入原生关闭按钮**: 在快捷输入面板左上角新增 macOS 系统原生关闭按钮，交互与系统窗口保持一致。
- 🖱️ **卡片双击编辑**: 新增 macOS 时间线卡片双击编辑能力，双击即可直接打开现有便签编辑器。

### 修复
- 🪟 **主窗口尺寸记忆**: 主窗口已启用 frame autosave，可稳定记住你手动调整后的窗口大小与位置。
- 🎯 **首次启动默认窗口行为**: 当没有历史窗口记录时，首次启动将以默认尺寸并居中打开；之后完全按用户调整结果记忆显示。
- 🌗 **快捷输入主题适配**: 快捷输入面板现已正确跟随浅色/深色/系统主题，不再被 HUD 样式强制为暗色外观。

---

## [2.5.2] - 2026-04-24

### Added
- 🗂️ **Remote Account Data Isolation by Name**: Each online account now stores data in its own folder under `~/Library/Application Support/Essays/<AccountName>`, with automatic path-safe name sanitization.

### Fixed
- 🔁 **Account Switch Flashing Data**: Prevented stale in-flight responses from a previous account from overwriting the current account view during account switching.
- 🚫 **Canceled Request Noise**: Suppressed cancellation-like transient errors to avoid misleading “Canceled” error popups during normal account transitions.

### Changed
- ✨ **Sparkle Upgrade**: Updated Sparkle dependency from `2.9.0` to `2.9.1`.
- ⚙️ **CI Sparkle Tool Sync**: Updated GitHub Actions release workflow Sparkle tool download from `2.9.0` to `2.9.1` to keep CI and local versions aligned.

---

### Chinese

### 新增
- 🗂️ **按账户名隔离远程数据目录**: 每个在线账户的数据现已独立存储在 `~/Library/Application Support/Essays/<账户名称>` 下，并自动进行路径安全清洗。

### 修复
- 🔁 **切换账户数据闪烁**: 修复了切换账户时旧请求回包覆盖当前账户视图，导致数据“一闪而过”的问题。
- 🚫 **已取消误报弹窗**: 屏蔽了取消类瞬态错误，避免正常账户切换过程中出现误导性的“已取消”错误提示。

### 变更
- ✨ **Sparkle 升级**: Sparkle 依赖已从 `2.9.0` 升级到 `2.9.1`。
- ⚙️ **CI Sparkle 工具同步**: GitHub Actions 发布流程中的 Sparkle 工具下载版本已同步更新到 `2.9.1`，确保 CI 与本地一致。

---

## [2.5.1] - 2026-04-24

### Fixed
- 💬 **Comment Badge Restoration (Online Mode)**: Restored timeline comment count badges for remote accounts by improving relation payload compatibility and decoding robustness.
- 🔁 **Comment Relation Direction Tolerance**: Comment counting now handles both relation directions to prevent missed badges when server relation orientation differs.
- 🧩 **API Relation Field Compatibility**: Added support for both `relations` and `relationList` response shapes to ensure stable comment metadata ingestion across Memos deployments.

---

### Chinese

### 修复
- 💬 **在线模式评论角标恢复**: 通过增强关系字段兼容性与解码健壮性，恢复了远程账户时间线中的评论数量角标显示。
- 🔁 **评论关系方向容错**: 评论计数现已同时兼容双向关系，避免因服务器关系方向差异导致角标漏计。
- 🧩 **API 关系字段兼容**: 同时支持 `relations` 与 `relationList` 两种返回结构，确保不同 Memos 部署下评论元数据稳定写入。

---

## [2.5.0] - 2026-04-24

### Added
- 📴 **Offline-First Architecture**: Complete redesign of the data synchronization layer. You can now compose, edit, and delete memos even without an internet connection.
- 📬 **Sync Queue View**: A new dedicated dashboard in the sidebar to monitor the status of pending local changes and background synchronization.
- ⚙️ **Background Sync Engine**: Intelligent background processing with exponential backoff retries and network status awareness.
- 🔄 **ID Mapping System**: Seamless transition from local temporary IDs to remote server IDs once synchronization is complete.

---

### Chinese

### 新增
- 📴 **离线优先架构**: 全面重构数据同步层。即使在没有网络连接的情况下，您也可以创作、编辑和删除笔记。
- 📬 **同步队列查看器**: 侧边栏新增专属面板，用于实时监控本地更改的挂起状态及后台同步进展。
- ⚙️ **后台同步引擎**: 具备网络状态感知能力的智能后台处理机制，支持指数退避重试算法。
- 🔄 **ID 自动映射系统**: 同步完成后，系统会自动将本地临时 ID 替换为远程服务器真实 ID，确保数据一致性。

---

## [2.2.4] - 2026-04-24

### Fixed
- 🔄 **Refresh Button Reliability**: Resolved a race condition at startup that occasionally made the manual refresh button appear ineffective.
- 🧹 **Ghost Memo Cleanup**: Fixed an issue where deleted memos from the server could reappear in the local view due to API filtering changes in newer Memos versions.
- 🗑️ **Local Deletion Consistency**: Improved local database handling to ensure memos deleted within the app are immediately removed from the local cache.

---

### Chinese

### 修复
- 🔄 **刷新按钮可靠性**: 解决了启动时的竞争条件问题，该问题曾导致手动刷新按钮偶尔失效。
- 🧹 **残留数据清理**: 修复了由于新版 Memos API 过滤逻辑变化导致的已删除笔记在本地视图中“复活”的问题。
- 🗑️ **本地删除一致性**: 优化了本地数据库处理逻辑，确保在应用内删除的笔记会立即从本地缓存中移除，避免重启后再次出现。

---

## [2.2.3] - 2026-04-23

### Fixed
- 📡 **Server Status Correction**: Fixed an issue where the server status incorrectly showed as offline due to a decoding mismatch with the Memos v0.27 `InstanceProfile` API.
- 🔄 **Stale Data Sync**: Implemented automatic synchronization on application launch to ensure memos deleted on the server are correctly removed from the local view.

---

### Chinese

### 修复
- 📡 **服务器状态修正**: 修复了由于 Memos v0.27 `InstanceProfile` API 结构变化导致的服务器状态异常显示为“离线”的问题。
- 🔄 **过时数据同步**: 实现了应用启动时的自动同步机制，确保服务器上已删除的笔记能及时从本地视图中移除。

---

## [2.2.2] - 2026-04-22

### Added
- 🚀 **Memos v0.27 Compatibility**: Fully migrated from numeric integer IDs to string-based resource names (UUIDs) for both memos and users, ensuring compatibility with the latest Memos release.
- 🛠️ **API Robustness**: Refactored core operations including update, delete, pin, and archive to use robust resource paths, eliminating dependency on deprecated ID extraction logic.

---

### Chinese

### 新增
- 🚀 **Memos v0.27 适配**: 全面迁移至基于字符串的资源名称 (UUID)，移除了对数字 ID 的依赖，确保与最新版 Memos 服务器的完美兼容。
- 🛠️ **API 稳定性**: 重构了更新、删除、置顶和归档等核心操作，采用更稳健的资源路径，彻底摒弃了已废弃的 ID 提取逻辑。

---

## [2.2.1] - 2026-04-17

### Improved
- 🌐 **Localization Robustness**: Replaced dynamic localization keys with stable, format-based rendering in memo counters to avoid untranslated runtime keys.
- 📡 **Connectivity State Accuracy**: Fixed server reachability state handling when server URL is empty, preventing stale "online" status in the UI.
- ⚙️ **Sidebar Rendering Performance**: Moved attachment and protected visibility counts to precomputed app state values to reduce repeated view-time calculations.

### Changed
- 🔌 **API Consistency**: Unified unarchive behavior through `MemosAPIClient` to avoid duplicated request logic and keep network handling centralized.
- 🧱 **Pagination Safety**: Removed unnecessary force-unwrapping in pagination loop conditions to improve maintainability and reduce crash risk during future refactors.

---

### Chinese

### 改进
- 🌐 **本地化健壮性**: 将笔记计数展示中的动态本地化键替换为稳定的格式化渲染，避免运行时 key 无法翻译的问题。
- 📡 **联网状态准确性**: 修复服务器地址为空时的可达性状态处理，避免界面残留“在线”状态。
- ⚙️ **侧边栏渲染性能**: 将附件数量和受保护可见性数量改为在应用状态中预计算，减少视图渲染时的重复计算。

### 变更
- 🔌 **API 一致性**: 将反归档行为统一收敛到 `MemosAPIClient`，避免重复请求逻辑并保持网络层集中管理。
- 🧱 **分页安全性**: 移除分页循环条件中的非必要强制解包，提升可维护性并降低后续重构中的崩溃风险。

## [2.2.0] - 2026-03-29

### Added
- 🚀 **Sparkle Updates**: Integrated Sparkle 2 framework for seamless automated updates on macOS.
- 🛠️ **Update Menu**: Added a "Check for Updates..." option in the app menu for manual update checks.
- 🌐 **Enhanced Release Flow**: Automated universal binary builds and localized release notes for English and Simplified Chinese.

### Chinese

### 新增
- 🚀 **Sparkle 自动更新**: 集成了 Sparkle 2 框架，为 macOS 用户提供无缝的自动更新体验。
- 🛠️ **更新菜单**: 在应用菜单中增加了“检查更新...”选项，方便手动触发更新检查。
- 🌐 **优化发布流程**: 实现了 Universal 架构自动构建，并提供中英文双语更新日志支持。

---

## [2.1.0] - 2026-03-28

### Added
- 🛡️ **Database Auto-Recovery**: Implemented a self-healing mechanism that automatically detects persistent startup crashes and resets the local database if a crash loop is detected, eliminating the need for manual cache deletion.

### Fixed
- 🚀 **Full Pagination Sync**: Fully implemented the Memos API v1 pagination protocol (`nextPageToken`). The app now fetches your entire memo collection regardless of size, fixing the previous 100-item limit.
- 🧱 **SwiftData Stability**: Resolved critical `EXC_BREAKPOINT` and unique constraint violation crashes by implementing a "Naked Insertion" and "Clean Room Transfer" strategy for global synchronization.
- 🧪 **Empty Sync Robustness**: Fixed a bug where deleting all memos from the server caused decoding failures and "ghost data" to reappear from the local cache.
- 🧹 **Concurrency Safety**: Refined internal API calls to achieve perfect Swift 6 strict concurrency compliance and removed redundant `await` calls.

### Chinese

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

### Chinese

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
