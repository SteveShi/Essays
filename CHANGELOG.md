# Changelog

All notable changes to this project will be documented in this file.

and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
