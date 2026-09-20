---
id: memos-v031-compatibility
title: Support Memos v0.31.0 Space Visibility and Metadata
category: decision
status: active
created: "2026-09-20T14:18:52"
updated: "2026-09-20T14:18:57"
---

<!-- compiled_truth -->
Memos v0.31.0 introduced Spaces collaboration, which adds `SPACE` to memo visibility and an optional `space` ("spaces/{space}") reference field.

### Decisions
1. **MemoVisibility Extension**: Added `case space = "SPACE"` with icon `person.2` and localized display name.
2. **Creatable Visibility Boundary**: Defined `MemoVisibility.creatableCases` (`[.public, .protected, .private]`) so Quick Capture and Compose panels only offer standalone visibility options, preventing accidental creation of orphaned Space memos without Space context.
3. **Model & Sync Persistence**: Added `spaceName: String?` to the SwiftData `Memo` entity and ensured `LocalDatabase.transferData` and `replaceLocalMemoId` persist and copy it.
4. **Sidebar Navigation**: Added `.spaceMemos` selection to `AppState.SidebarSelection` and displayed it conditionally in `SidebarView` when `metrics.spaceCount > 0`.


## Timeline

- time: 2026-09-20T14:18:52
  kind: decision
  summary: "Created this page: Support Memos v0.31.0 Space Visibility and Metadata"
  source: Memos v0.31.0 upgrade
  affects: [memos-v031-compatibility]

- time: 2026-09-20T14:18:57
  kind: decision
  summary: "Memos v0.31.0 introduced Spaces collaboration with SPACE visibility and space metadata on memos. Essays supports decoding SPACE visibility, storing spaceName, and filtering in sidebar, while restricting standalone creation to creatableCases."
  source: Memos v0.31.0 Release
  affects: [memos-v031-compatibility]
