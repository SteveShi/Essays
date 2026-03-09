# Contributing to Essays

First off, thank you for considering contributing to Essays! It's people like you that make it a great tool for everyone.

## Code of Conduct

By participating in this project, you are expected to uphold our Code of Conduct. Please be respectful and professional in all interactions.

## How Can I Contribute?

### Reporting Bugs

- **Check existing issues**: Before opening a new issue, please search the tracker to see if the bug has already been reported.
- **Use the template**: If you find a bug, please use the bug report template (if available) or provide as much detail as possible, including your macOS version, Essays version, and steps to reproduce.

### Suggesting Enhancements

- **Open an issue**: Describe the enhancement you'd like to see and why it would be useful.
- **Discuss**: Engage in the discussion if others provide feedback or ask questions.

### Pull Requests

1. **Fork the repository** and create your branch from `main`.
2. **Setup the environment**:
   - Install Xcode 16.0 or newer.
   - The project uses `xcodegen`. If you make changes to the project structure, please update `project.yml`.
3. **Draft your changes**:
   - Follow the existing code style (SwiftUI, Swift 6 concurrency patterns).
   - Ensure the app builds without errors.
4. **Submit the PR**:
   - Provide a clear description of the changes.
   - Reference any related issues.

## Style Guide

- Use **SwiftUI** for all UI components.
- Follow the **Liquid Glass** theme patterns defined in `Theme/`.
- Use **Swift Concurrency** (`async/await`, `Task`) for asynchronous operations.
- Keep localizations updated in `Localizable.xcstrings`.

---

Thank you for your help!
