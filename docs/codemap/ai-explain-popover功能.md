# AI 解释下拉对话功能 CodeMap

## 目标范围

本索引覆盖“点击解释后以豆包式下拉框展示 AI 解释结果，并支持继续对话”的相关代码路径。范围包括查询窗口标题栏、查询模型、AI 服务复用点、设置项持久化和本地化，不包含常规翻译服务排序和 OCR 主流程。

## UI 入口与窗口结构

- `Easydict/objc/ViewController/View/Titlebar/EZTitlebar.m`
  - 负责查询窗口标题栏右侧按钮组、快捷动作菜单和 pin 按钮。
  - 当前 `NSStackView` 为 `NSUserInterfaceLayoutDirectionRightToLeft`，按钮从右向左排列。
  - 适合新增 `explainButton`，点击后由 Swift 桥接类展示 `NSPopover`。

- `Easydict/objc/ViewController/View/Titlebar/EZTitlebar.h`
  - 暴露标题栏按钮属性给快捷键和外部调用。
  - 新按钮如果只在标题栏内部使用，可以不暴露；如果后续快捷键需要触达，再补公开属性。

- `Easydict/objc/ViewController/Window/BaseQueryWindow/EZBaseQueryViewController.h/m`
  - 持有 `queryModel`、`services`，负责查询窗口表格和结果刷新。
  - `queryModel.queryText` 是解释功能的输入源。
  - 标题栏可通过 `self.window` 转为 `EZBaseQueryWindow`，再取 `queryViewController.queryModel`。

- `Easydict/Swift/Feature/Markdown/MarkdownLabel.swift`
  - 现有 Markdown 渲染能力在结果区使用。
  - SwiftUI 下拉框可以先用 `Text(.init(markdown))`/普通 `Text` 展示，后续如需更强 Markdown 可复用此方向。

## AI 服务与协议复用点

- `Easydict/Swift/Service/OpenAI/StreamService.swift`
  - LLM 服务共同基类，已有模型、API Key、endpoint、prompt、temperature、streaming 等配置键模式。
  - 可参考 `stringDefaultsKey` / `serviceDefaultsKey` 的命名策略，但 AI 解释不应混入翻译服务列表。

- `Easydict/Swift/Service/OpenAI/BaseOpenAIService.swift`
  - OpenAI Chat Completions 兼容请求、流式与非流式处理。
  - 解释功能可复用其消息结构思想，但建议新建小型 client，避免强耦合 `QueryService` 的翻译结果状态。

- `Easydict/Swift/Service/Claude/ClaudeService.swift`
  - Anthropic Messages API 请求和 SSE 解析入口。
  - 关键差异：鉴权使用 `x-api-key`，系统提示词是顶层 `system` 字段，消息不接受 `system` role。

- `Easydict/Swift/Service/Claude/ClaudeSSEParser.swift`
  - 现有 Claude SSE 解析器，解释功能的 Anthropic 流式解析可以优先复用或提取同类逻辑。

- `Easydict/Swift/Service/OpenAI/ChatMessage.swift`
  - 已有 `ChatMessage` 和 role 定义。
  - 如访问级别允许，可复用为解释会话消息模型；否则在解释功能模块内定义独立模型。

## 设置与持久化

- `Easydict/Swift/Feature/Configuration/Defaults.Keys+Extension.swift`
  - 全局设置键集中定义位置。
  - 解释功能需要新增 provider、apiURL、apiKey、model、systemPrompt、enabled 等 key。

- `Easydict/Swift/View/SettingView/Tabs/TabView/GeneralTab.swift`
  - 已有 Quick Link 和显示类全局配置。
  - 解释入口是否显示属于全局窗口体验，适合新增“AI 解释”配置 Section，或在 Service 页加入独立非翻译服务配置。

- `Easydict/Swift/View/SettingView/Tabs/ServiceConfigurationView/ServiceCells.swift`
  - 可复用 `InputCell`、`SecureInputCell`、`ToggleCell`。

- `Easydict/Swift/View/SettingView/Tabs/ServiceConfigurationView/TextEditorCell.swift`
  - 可复用为系统提示词输入。

## 本地化

- `Easydict/App/Localizable.xcstrings`
  - 所有可见文案必须补齐当前 catalog 中已有语言：`en`、`ja`、`sk`、`zh-Hans`、`zh-Hant`。
  - 新 key 建议使用 `ai_explain.*` 或 `setting.general.ai_explain.*` 前缀。

## Xcode 工程

- `Easydict.xcodeproj/project.pbxproj`
  - 新增 Swift/ObjC/资源文件必须加入对应 group。
  - 文档类文件按仓库规则也应加 `PBXFileReference`，但不加入 build phases，除非明确要随 app 打包。

## 风险点

- 查询窗口主要是 Objective-C/AppKit，新的对话 UI 更适合 SwiftUI，但需要 `NSHostingController` 或 `NSPopover` 桥接。
- 解释对话必须取消旧请求，防止关闭 popover 后后台继续写状态。
- OpenAI 兼容和 Anthropic 兼容的 endpoint/body/header 不同，不应把 Anthropic 伪装成 OpenAI。
- API Key 属敏感配置，至少应使用现有 `SecureInputCell`；若后续统一迁移 Keychain，需要再开单。
