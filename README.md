# Essays

**Essays** is a native macOS client for the [Memos](https://usememos.com) self-hosted note-taking service. It provides a seamless and lightweight experience for capturing thoughts, logging daily activities, and organizing inspiration.

## Features

- 📱 **Universal App**: Full native support for macOS, iPadOS, and iOS, providing a seamless experience across all your devices.
- 🔀 **Three-Column Navigation**: A responsive, standard `NavigationSplitView` ensuring optimal use of screen real estate (Sidebar, Timeline, and Details).
- ✨ **Premium Native UI**: A "LiquidGlass" aesthetic with glassmorphism, thin materials, and subtle micro-animations.
- 🤖 **Apple AI Assistant**: Integrated Foundation Models for on-device text processing and intelligence.
- 🚀 **Quick Capture & Global Shortcuts**: Record thoughts instantly from anywhere on your Mac using customizable global hotkeys.
- 🖼️ **Attachments Gallery**: A dedicated grid view in the sidebar to easily browse all your image memos.
- 🔍 **Rich Media Previews**: Native Apple Quick Look for image attachments and interactive MapKit popovers for location tags.
- 📅 **Interactive Calendar**: A reactive Monthly Calendar directly in the sidebar to filter your daily logs.
- 🕒 **Timeline View**: A beautifully organized chronological feed of your memos, grouped by date.
- 🌍 **Fully Localized**: Complete support for English and Simplified Chinese.
- 🔒 **Privacy First**: Direct connection to your self-hosted Memos server via Access Tokens.

## Apple AI Assistant

Leverage the power of Apple's on-device Foundation Models to enhance your brainstorming and note-taking:

- ✨ **Summarize**: Generate concise summaries of long memos.
- ✏️ **Improve Writing**: Polish grammar, tone, and clarity.
- 📝 **Expand**: Elaborate on brief ideas with more detail.
- 🏷️ **Generate Tags**: Automatically suggest relevant tags.
- 💡 **Related Ideas**: Unlock new perspectives with AI-generated connections.

All AI processing happens **locally on your Mac**, ensuring your thoughts and data remain completely private.

## Installation

### Direct Download
Download the latest `.dmg` or `.app` from the [Releases](https://github.com/lpgneg19/Essays/releases) page.

### Homebrew
Install via Homebrew tap:
```bash
brew tap lpgneg19/tap
brew install --cask essays
```

### Build from Source
1. Clone the repository.
2. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
3. Run `xcodegen generate` in the project root.
4. Open `Essays.xcodeproj` and run.

## Configuration

On the first launch, you will be prompted to enter:
- **Server URL**: The address of your Memos instance (e.g., `https://memos.example.com`).
- **Access Token**: Your personal access token from Memos settings.

## License

This project is licensed under the [Mozilla Public License 2.0](LICENSE).

---

[View Chinese Version / 切换至中文版](README.zh-CN.md)
