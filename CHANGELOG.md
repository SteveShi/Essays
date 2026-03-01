# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
