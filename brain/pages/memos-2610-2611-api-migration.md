---
id: memos-2610-2611-api-migration
title: "Migrate to Memos 26.10+ Unversioned REST Paths and 26.11.2 Parent-Based Comments"
category: decision
status: active
tags: [api, memos, comments]
created: "2026-11-22T22:25:56"
updated: "2026-11-22T22:26:12"
---

<!-- compiled_truth -->
Memos transitioned from `v0.31.0` to calendar versioning (`26.10.0` .. `26.11.2`) with two major breaking API changes that Essays adapts to directly in `MemosAPIV1` (building on [[memos-api-v1-standardization]] and [[memos-v031-compatibility]]):

### 1. Unversioned REST Routes (Memos 26.10.0+)
- All REST endpoints dropped the `/v1` segment (`/api/v1/...` now returns `410 Gone` or is removed) and moved to `/api/...` (`/api/instance/profile`, `/api/auth/signin`, `/api/auth/me`, `/api/memos`, `/api/attachments`, `/api/{name=memos/*}`, `/api/{parent=memos/*}/attachments`).
- `UpdateMemo` strictly validates `updateMask` against `content`, `visibility`, `space`, `pinned`, `state`, `create_time`, `update_time`, `location`, `attachments`, and `relations`. Since `tags` is an `OUTPUT_ONLY` server-extracted field, `"tags"` is omitted from `updateMask`.
- `CreateMemo` ignores `pinned` on creation; when `pinned == true` is requested at creation time, `MemosAPIV1.createMemo` follows up with `togglePinMemo`.

### 2. Comments as Memos with `parent` (Memos 26.11.2+)
- `GET /api/memos/{memo}/comments` (`ListMemoComments`), `POST /api/memos/{memo}/comments` (`CreateMemoComment`), and `MemoRelation.Type.COMMENT` are removed.
- `MemoService.ListMemos` (`GET /api/memos`) now returns comments by default; top-level memo sync (`fetchMemosByState`) passes `filter: "parent == null"`.
- Listing comments (`fetchComments`) queries `GET /api/memos` with `filter: parent == "memos/{memo}"`.
- Creating a comment (`createComment`) calls `POST /api/memos` (`CreateMemo`) with `parent: "memos/{memo}"`.
- SwiftData `Memo` stores `parentName: String?` (`Memo.parent`) and `remoteCommentCount: Int` (`Memo.comment_count`), excluding any memo with a non-empty `parentName` from top-level timeline and sidebar metrics via `isSystemCommentMemo`.


## Timeline

- time: 2026-11-22T22:25:56
  kind: decision
  summary: "Created this page: Migrate to Memos 26.10+ Unversioned REST Paths and 26.11.2 Parent-Based Comments"
  source: "Memos 26.10.0 & 26.11.2 Releases"
  affects: [memos-2610-2611-api-migration]

- time: 2026-11-22T22:26:12
  kind: decision
  summary: Adapt MemosAPIV1 and Memo model to Memos 26.10.0 unversioned /api/ routes and 26.11.2 parent-based comment model
  source: "Memos 26.10.0 & 26.11.2 Releases"
  affects: [memos-2610-2611-api-migration]
