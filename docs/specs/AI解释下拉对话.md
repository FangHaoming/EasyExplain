# AI 解释下拉对话 Spec

## 0. 状态

- Phase: Plan
- Approval Status: Waiting for `Plan Approved`
- Active Project: Easydict
- Active Workdir: `/Users/fanghaoming/conductor/workspaces/EasyExplain/moscow`
- Spec Path: `docs/specs/AI解释下拉对话.md`
- Codemap Used: `docs/codemap/ai-explain-popover功能.md`

## 1. Research Findings

### 1.1 需求快照

用户希望在查询窗口点击“解释”后，出现类似截图中豆包的下拉浮层，浮层内展示 AI 解释结果，并支持继续对话。AI 解释服务需要支持 OpenAI 兼容和 Anthropic 兼容协议，用户可配置 API URL、API Key、model、系统提示词。

### 1.2 截图事实

截图展示的是一个深色圆角浮层，锚定在被选中文本附近，上方有标题“这里是我的解释”，中间区域展示 Markdown 风格回答，底部语义上应支持继续输入对话。目标体验不是把解释结果追加到翻译结果列表，而是由“解释”按钮打开独立下拉对话框。

### 1.3 代码事实

- 查询窗口标题栏由 `Easydict/objc/ViewController/View/Titlebar/EZTitlebar.m` 维护。
- 查询窗口控制器 `EZBaseQueryViewController` 持有 `queryModel`，其中 `queryText` 是当前输入或选中文本。
- 项目已有 `StreamService`、`BaseOpenAIService`、`ClaudeService`，可参考现有 OpenAI/Anthropic 请求方式。
- 设置页使用 SwiftUI `Form`，通用输入控件在 `ServiceCells.swift` 和 `TextEditorCell.swift`。
- 偏好项集中在 `Defaults.Keys+Extension.swift`，用户可见文案集中在 `Localizable.xcstrings`。

### 1.4 方案结论

采用“独立 AI 解释模块 + AppKit 标题栏桥接 + SwiftUI Popover 内容”的方案：

- 不把 AI 解释注册为普通翻译服务，避免它出现在服务列表和自动翻译队列。
- 新增独立配置键和设置区块，保存 provider、API URL、API Key、model、系统提示词、显示入口开关。
- 标题栏新增“解释”按钮，读取当前 `queryModel.queryText` 并打开 `NSPopover`。
- Popover 内部使用 SwiftUI view model 管理解释请求、会话消息、继续提问、取消和错误。
- OpenAI 兼容与 Anthropic 兼容使用同一领域接口，不共享错误的 body/header。

### 1.5 In Scope

- 查询窗口标题栏新增可点击的“解释”按钮。
- 点击后以下拉 `NSPopover` 展示 AI 解释会话。
- 首次打开自动用当前查询文本请求解释。
- 支持在 popover 内继续输入追问，保留本次会话上下文。
- 支持 OpenAI 兼容 Chat Completions。
- 支持 Anthropic 兼容 Messages API。
- 支持配置 API URL、API Key、model、系统提示词、provider、是否显示解释按钮。
- 新增可见文案的 string catalog 本地化。

### 1.6 Out of Scope

- 不新增单元测试。仓库规则要求同一 agent session 不同时修改生产代码和测试；本次是 UI/服务集成。
- 不新增快捷键。
- 不接入翻译服务排序、自动查询或历史记录。
- 不实现跨会话持久化聊天记录。
- 不做 Keychain 迁移，沿用项目现有 Defaults + SecureInputCell 配置习惯。

### 1.7 Open Questions

- “解释”按钮是否需要在设置中默认显示？已确认：需要默认显示。
- AI 解释结果是否要支持完整 Markdown 渲染？已确认：不需要完整 Markdown 渲染，使用 SwiftUI 基础 Markdown 即可。
- Anthropic 兼容 endpoint 默认使用 `https://api.anthropic.com/v1/messages`，OpenAI 兼容默认使用 `https://api.openai.com/v1/chat/completions`。

### 1.8 Acceptance Criteria

- 用户可在设置中选择 OpenAI 兼容或 Anthropic 兼容，并配置 API URL、API Key、model、系统提示词。
- 查询窗口中出现本地化 tooltip/title 的“解释”按钮，设置关闭后不显示。
- 当前 query text 为空时点击解释，不发请求，并在 popover 内显示本地化空文本提示。
- 当前 query text 非空且配置完整时，popover 自动请求解释并显示结果。
- 用户可在 popover 底部继续追问，追问会带上同一 popover 会话历史。
- 关闭 popover 或点击取消后，正在进行的请求被取消。
- API 错误、空 API Key、无效 URL 以用户可读错误展示。
- 所有新增 Swift 类型有类型级英文文档注释。
- 所有新增 Swift/ObjC 文件加入 Xcode 工程 navigator。

## 2. Architecture & Strategy

跳过 Innovate。理由：需求已有明确 UI 目标，项目存在可参考的 LLM 服务实现和 AppKit/SwiftUI 混合模式；不需要多方案架构评审。

核心边界：

- `AIExplainClient` 只负责协议请求和流式内容输出。
- `AIExplainViewModel` 只负责 UI 状态、会话消息和请求生命周期。
- `AIExplainPopoverPresenter` 只负责从 Objective-C 标题栏打开/关闭 `NSPopover`。
- `EZTitlebar` 只负责按钮显示、tooltip 和点击事件，不包含网络逻辑。

## 3. Detailed Design & Implementation

### 3.1 File Changes

新增：

- `Easydict/Swift/Feature/AIExplain/AIExplainProvider.swift`
- `Easydict/Swift/Feature/AIExplain/AIExplainMessage.swift`
- `Easydict/Swift/Feature/AIExplain/AIExplainConfiguration.swift`
- `Easydict/Swift/Feature/AIExplain/AIExplainClient.swift`
- `Easydict/Swift/Feature/AIExplain/AIExplainViewModel.swift`
- `Easydict/Swift/Feature/AIExplain/AIExplainPopoverView.swift`
- `Easydict/Swift/Feature/AIExplain/AIExplainPopoverPresenter.swift`

修改：

- `Easydict/Swift/Feature/Configuration/Defaults.Keys+Extension.swift`
- `Easydict/Swift/Feature/Configuration/MyConfiguration.swift`
- `Easydict/Swift/View/SettingView/Tabs/TabView/GeneralTab.swift`
- `Easydict/objc/ViewController/View/Titlebar/EZTitlebar.h`
- `Easydict/objc/ViewController/View/Titlebar/EZTitlebar.m`
- `Easydict/App/Localizable.xcstrings`
- `Easydict.xcodeproj/project.pbxproj`

如实现中发现目录文档规则被新目录触发，还需要新增：

- `Easydict/Swift/Feature/AIExplain/ai-explain-overview.html`
- `Easydict/Swift/Feature/AIExplain/ai-explain-architecture.svg`

### 3.2 Signatures

#### `AIExplainProvider.swift`

- `enum AIExplainProvider: String, CaseIterable, Defaults.Serializable, CustomLocalizedStringResourceConvertible`
  - `case openAICompatible`
  - `case anthropicCompatible`
  - `var localizedStringResource: LocalizedStringResource { get }`
  - `var defaultEndpoint: String { get }`
  - `var defaultModel: String { get }`

#### `AIExplainMessage.swift`

- `struct AIExplainMessage: Identifiable, Equatable`
  - `enum Role: String, Codable`
  - `let id: UUID`
  - `let role: Role`
  - `var content: String`

#### `AIExplainConfiguration.swift`

- `struct AIExplainConfiguration`
  - `let provider: AIExplainProvider`
  - `let endpoint: String`
  - `let apiKey: String`
  - `let model: String`
  - `let systemPrompt: String`
  - `static var current: AIExplainConfiguration { get }`

#### `AIExplainClient.swift`

- `final class AIExplainClient`
  - `func streamExplain(text: String, messages: [AIExplainMessage], configuration: AIExplainConfiguration) -> AsyncThrowingStream<String, Error>`
  - `func cancel()`
  - `private func openAIStream(...) -> AsyncThrowingStream<String, Error>`
  - `private func anthropicStream(...) -> AsyncThrowingStream<String, Error>`
  - `private func validate(configuration: AIExplainConfiguration) throws`

#### `AIExplainViewModel.swift`

- `@MainActor final class AIExplainViewModel: ObservableObject`
  - `@Published private(set) var messages: [AIExplainMessage]`
  - `@Published var inputText: String`
  - `@Published private(set) var isLoading: Bool`
  - `@Published private(set) var errorMessage: String?`
  - `init(queryText: String, client: AIExplainClient = AIExplainClient())`
  - `func startInitialExplain()`
  - `func sendFollowUp()`
  - `func cancel()`

#### `AIExplainPopoverView.swift`

- `struct AIExplainPopoverView: View`
  - `init(queryText: String, onClose: @escaping () -> Void)`

#### `AIExplainPopoverPresenter.swift`

- `@objcMembers final class AIExplainPopoverPresenter: NSObject`
  - `static let shared: AIExplainPopoverPresenter`
  - `func toggle(anchorView: NSView, queryText: String)`
  - `func close()`

#### `Defaults.Keys+Extension.swift`

- `static let enableAIExplain = Key<Bool>("EZConfiguration_kEnableAIExplain", default: true)`
- `static let aiExplainProvider = Key<AIExplainProvider>("EZConfiguration_kAIExplainProvider", default: .openAICompatible)`
- `static let aiExplainAPIURL = Key<String>("EZConfiguration_kAIExplainAPIURL", default: "")`
- `static let aiExplainAPIKey = Key<String>("EZConfiguration_kAIExplainAPIKey", default: "")`
- `static let aiExplainModel = Key<String>("EZConfiguration_kAIExplainModel", default: "")`
- `static let aiExplainSystemPrompt = Key<String>("EZConfiguration_kAIExplainSystemPrompt", default: defaultAIExplainSystemPrompt)`

#### `EZTitlebar`

- `@property (nonatomic, strong) EZOpenLinkButton *explainButton;`
- `- (void)showAIExplainPopover;`

### 3.3 UI 行为

- 标题栏按钮使用 SF Symbol `sparkles` 或项目可用的 symbol image helper。
- tooltip 使用 `ai_explain.button.tooltip`。
- popover 尺寸建议 `560 x 520`，最大高度不超过屏幕可见区域，深浅色跟随系统。
- 顶部展示标题 `ai_explain.popover.title` 和关闭按钮。
- 内容区按消息角色展示，初始 assistant 消息流式追加。
- 解释结果使用 SwiftUI 基础 Markdown 展示，不引入完整 Markdown renderer 或 WebView。
- 底部为输入框和发送按钮；加载时发送按钮禁用，并显示取消按钮或进度。

### 3.4 Prompt

默认系统提示词：

```text
You are a concise explanation assistant. Explain the selected text in the user's language. Focus on meaning, context, key terms, and practical examples. Use clear Markdown. Do not translate only unless translation is necessary for the explanation.
```

首次用户消息格式：

```text
Explain the following text:

"""
{queryText}
"""
```

追问直接发送用户输入，并保留本次 popover 的历史消息。

### 3.5 Validation

- Swift/Objective-C 源码变更超过 100 行，按仓库规则需要运行：

```bash
xcodebuild build -workspace Easydict.xcworkspace -scheme Easydict | xcbeautify
```

- 如果默认 DerivedData 出现权限或缓存问题，改用：

```bash
xcodebuild build -workspace Easydict.xcworkspace -scheme Easydict -derivedDataPath ~/Library/Developer/Xcode/DerivedData/Easydict-Temporary | xcbeautify
```

并在结束前删除该临时 DerivedData。

### 3.6 Checklist

1. 回读本 Spec 的 Plan 区块，确认仍为 `Plan Approved` 后再实施。
2. 新增 `AIExplain` Swift 文件和类型级文档注释。
3. 新增 `AIExplainProvider` Defaults bridge 和配置读取。
4. 实现 OpenAI 兼容流式请求、错误处理、取消。
5. 实现 Anthropic 兼容流式请求、错误处理、取消。
6. 实现 `AIExplainViewModel` 的初始解释、追问、取消和错误状态。
7. 实现 `AIExplainPopoverView`。
8. 实现 `AIExplainPopoverPresenter` 的 Objective-C 可调用桥接。
9. 修改 `EZTitlebar`，按配置显示解释按钮并打开 popover。
10. 在 `GeneralTab` 增加 AI 解释设置区块。
11. 更新 `MyConfiguration` 监听，使显示开关变化后刷新标题栏按钮。
12. 更新 `Localizable.xcstrings` 全部现有语言。
13. 更新 `Easydict.xcodeproj/project.pbxproj`。
14. 如新目录文档规则触发，补齐 AIExplain overview HTML 和 SVG，并加入 project navigator。
15. 运行 `xcodebuild build` 验证。
16. 回写 Execute Log 和 Review 结论到本 Spec。

## 4. Execute Log

### 4.1 Implemented

- 新增 `Easydict/Swift/Feature/AIExplain/` 模块：
  - `AIExplainProvider`
  - `AIExplainMessage`
  - `AIExplainConfiguration`
  - `AIExplainClient`
  - `AIExplainViewModel`
  - `AIExplainPopoverView`
  - `AIExplainPopoverPresenter`
- 新增 AIExplain 目录概览 HTML 和架构 SVG。
- 新增 Defaults 配置键：
  - `enableAIExplain`
  - `aiExplainProvider`
  - `aiExplainAPIURL`
  - `aiExplainAPIKey`
  - `aiExplainModel`
  - `aiExplainSystemPrompt`
- 在 `GeneralTab` 增加 AI 解释设置区块。
- 在 `MyConfiguration` 监听 `enableAIExplain`，变化后刷新标题栏按钮。
- 在 `EZTitlebar` 增加解释按钮，点击后读取当前 `queryModel.queryText` 并打开 SwiftUI popover。
- 更新 `Localizable.xcstrings`，新增 key 覆盖 `en`、`ja`、`sk`、`zh-Hans`、`zh-Hant`、`es`。
- 更新 `Easydict.xcodeproj/project.pbxproj`，将 AIExplain Swift 文件加入 Sources，将 HTML/SVG 加入 Xcode navigator。
- 结构校验通过：
  - `python3 -m json.tool Easydict/App/Localizable.xcstrings`
  - `rsvg-convert Easydict/Swift/Feature/AIExplain/ai-explain-architecture.svg`
  - `grep` 确认 `AIExplainClient.swift in Sources`

### 4.2 Validation Blocker

`xcodebuild build -workspace Easydict.xcworkspace -scheme Easydict | xcbeautify` 未完成：

- `xcbeautify` 在当前环境中不存在。
- 直接运行 `xcodebuild build -workspace Easydict.xcworkspace -scheme Easydict` 时，Xcode 停在 Resolve Package Graph。
- 截图和命令输出均显示阻塞点为 SwiftPM 包 `swift-protobuf` checkout `1.33.3` 时无法更新 `protobuf` 子模块：
  - `Couldn't update repository submodules`
  - `Resolving Package Graph Failed`
- 追加尝试 `-disableAutomaticPackageResolution` 仍停在 Resolve Package Graph，无法进入源码编译阶段。

因此本轮无法获得 Xcode 编译结果；当前验证覆盖结构、资源和工程引用，不覆盖 Swift/ObjC 编译。

## 5. Review

待后续能够完成 Xcode package resolution 后执行完整 `review_execute`。
