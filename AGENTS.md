# AGENTS.md - Essays Agent Playbook

面向在 `Essays` 仓库执行任务的代理。目标是高质量交付、最小风险改动、可验证结果。

## Quick Reference

- 代码语言：Swift 6.0+
- 工程来源：`project.yml`（先 `xcodegen generate` 再用 `Essays.xcodeproj`）
- 核心约束：
  - 只要是用户可见文本，必须走 `Resources/Localizable.xcstrings`
  - 禁止硬编码文案
  - 禁止无必要实体膨胀（Entities should not be multiplied without necessity）
  - no legacy fallback
  - Bundle Identifier 格式：`com.steveshi.appname`
- 默认沟通语言：中文

## Workflow Rules

1. 先读代码与真实上下文，再改动；优先复用现有 API，不重复造接口。
2. 改动保持最小闭环，只碰任务相关文件。
3. 若改动涉及 `project.yml`，必须执行：
   - `xcodegen generate`
4. 完成修改后执行构建验证（代码改动场景必须）：
   - `xcodebuild -project Essays.xcodeproj -scheme Essays -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`
5. 清理本次临时产物（`*.log` / `*.txt`），不要留下任务噪音文件。

## Repository Map

- App 入口：`EssaysApp.swift`
- 状态与数据模型：`Models/`
- 同步与 API：`Services/`
  - `Services/SyncEngine.swift`
  - `Services/MemosAPIClient.swift`
- 视图层：`Views/`
- 本地化：`Resources/Localizable.xcstrings`
- 版本与构建定义：`project.yml`
- 发布记录：`CHANGELOG.md`
- API 经验文档：`Documentation/MEMOS_API_KNOWLEDGE.md`

## Coding Conventions

- 所有可见字符串必须本地化；不要直接写死在 SwiftUI 视图或服务层。
- 遵守 Apple 平台编码规范，按功能分目录组织代码。
- 优先兼容当前服务端真实返回结构，谨慎处理 API 字段漂移。
- 修改时避免引入无关重构，不做“顺手大改”。

## Build & Release Guardrails

- 版本更新必须同步更新：
  - `project.yml` 里的版本字段
  - `CHANGELOG.md` 的中英文发布说明
- `CHANGELOG.md` 格式要求（Sparkle 友好）：
  - 英文在前
  - 使用 `---` 分隔
  - 中文在后
- 严禁修改 `MDWriter/.github/workflows/release.yml` 中已验证有效的以下逻辑：
  - `Extract Version`
  - `Extract Release Notes`
- Sparkle 2.x 发布签名链路保持现状：
  1. 私钥清洗：`tr -dc A-Za-z0-9+/=`
  2. 设置 `DYLD_FRAMEWORK_PATH` 到 Sparkle tools 目录
  3. stdin 签名：`echo "$KEY" | generate_appcast --ed-key-file -`

## Definition of Done

- 改动满足需求且范围受控。
- 代码改动场景下构建通过。
- 无新增硬编码可见文案。
- 无新增临时日志垃圾文件。
- 说明清楚“改了什么、为什么、如何验证”。
