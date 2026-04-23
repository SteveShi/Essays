# Memos API v1 (v0.22+) 规范与持久记忆 (中文)

本项目使用 Memos 的 `v1` REST API，特别是针对 v0.22.x 及以上版本的改进协议。

## 1. 核心机制 (中文)

### 资源名称 (Resource Names) (中文)
v1 API 使用资源名称而非简单的 ID：
- **格式**: `memos/{uuid}` 或 `users/{username}`
- **示例**: `memos/abc-123-efg`, `users/alice`
- **注意**: 在 `PATCH` 和 `DELETE` 请求中，资源名称必须经过 URL 编码（例如 `/` 编码为 `%2F`）。

- **Header**: `Authorization: Bearer <TOKEN>`
- **SignIn (v0.27+)**: `POST /api/v1/auth/signin` 使用 `passwordCredentials` 并在响应体中获取 `accessToken`。
- **Content-Type**: `application/json`

---

## 2. 数据结构模型 (中文)

### Memo (闪念) (中文)
- **name**: 资源全名 (e.g., `memos/123`)
- **content**: Markdown 文本内容
- **visibility**: 可见性 (`PUBLIC`, `PROTECTED`, `PRIVATE`)
- **pinned**: 是否置顶 (Bool)
- **createTime / updateTime**: ISO8601 时间戳
- **tags**: 标签数组
- **attachments / resources**: 附件对象数组

### Attachment (附件/资源) (中文)
- **name**: 资源名 (e.g., `resources/456`)
- **filename**: 原始文件名
- **type**: MIME 类型 (e.g., `image/png`)
- **externalLink**: 外部链接（如果存在）
- **content**: 上传时的 Base64 数据

---

## 3. 关键 API 端点 (Endpoints) (中文)

| 功能 (中文) | 方法 (中文) | 路径 (中文) | 参数/说明 (中文) |
| :--- | :--- | :--- | :--- |
| **获取 Memos** | `GET` | `/api/v1/memos` | `pageSize=100`, `state=NORMAL` (或 `ARCHIVED`) |
| **创建 Memo** | `POST` | `/api/v1/memos` | Body: `{ content, visibility, pinned, ... }` |
| **更新 Memo** | `PATCH` | `/api/v1/{encoded_name}` | 使用 `updateMask` 参数指定更新字段 |
| **删除 Memo** | `DELETE` | `/api/v1/{encoded_name}` | 彻底删除资源 |
| **上传附件** | `POST` | `/api/v1/attachments` | Body: `{ filename, type, content (base64) }` |
| **获取当前用户** | `GET` | `/api/v1/auth/me` | 返回登录用户详细信息 |
| **服务器状态** | `GET` | `/api/v1/instance/profile` | 检查版本及服务器配置 |

---

## 4. 最佳实践与注意事项 (Development Tips) (中文)

1. **日期解析**: Memos 返回的时间戳可能包含微秒，解码时优先使用 `ISO8601DateFormatter` 并开启 `.withFractionalSeconds`。
2. **更新掩码 (Update Mask)**: 使用 `PATCH` 时，必须提供 `updateMask` 查询参数（如 `?updateMask=content,pinned`），否则服务器可能忽略部分字段。
3. **标签处理**: 新版 Memos 可能不再提供统一的 `/api/v1/tags` 接口。建议从 `memos` 列表返回的对象中动态提取。
4. **性能缓存**: `AppState` 中建议预计算常用的统计数据（如今日笔记数、公开笔记数），避免在 SwiftUI 视图刷新时进行重复循环计算。
