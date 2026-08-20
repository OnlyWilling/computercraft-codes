---
name: basalt
description: 使用仓库最新版 Basalt 为 CraftOS/CC:Tweaked 设计、实现和审查 Lua UI；API 细节查知识库，经验遵循事件驱动和小屏适配原则
---

# Basalt UI 开发 Skill

## 适用范围

处理 Minecraft ComputerCraft / CC:Tweaked 中基于 Basalt 的 Lua UI：页面、Frame、Label、Button、Input、事件、Timer、窗口和后续 widget。

## 开始工作前

1. 先阅读 [`docs/knowledge/basalt/README.md`](../../docs/knowledge/basalt/README.md)，确认当前版本和资料优先级。
2. API 细节优先查 [`docs/knowledge/basalt/api/core.md`](../../docs/knowledge/basalt/api/core.md)；特定 widget 先查 `api/` 对应文件，再查 `wiki/` 原文。
3. 以仓库最新版 [`Basalt/basalt.lua`](../../Basalt/basalt.lua) 为默认目标；只有用户明确要求时才按 `Basalt/basalt25.lua` 兼容。
4. 阅读目标项目已有 UI，匹配其命名、缩进、页面切换和错误反馈风格。

## API 使用规则

- 不凭记忆猜测 widget 参数、事件参数或版本能力；知识库没有记录时，先读对应 wiki Markdown 或源码。
- 优先使用已确认的链式 API：`createFrame`、`addLabel`、`addButton`、`addInput`、`setPosition`、`setSize`、`setText`、`getText`、`setBackground`、`onClick`、`clear`、`close`。
- 应用层只使用 widget 的公开 API；不要依赖 minified 文件内部局部变量或继承实现细节。
- 新增 API 知识时标记 `verified`、`example` 或 `待验证`，并记录来源和版本。

## UI 设计规则

- 页面按“状态 + 渲染函数”组织；页面切换时清理旧内容或明确复用控件。
- 回调按“读取 → 规范化 → 校验 → 业务 → 持久化 → 反馈”顺序编写。
- 输入一律当作字符串处理，显式转换并验证空值、范围和枚举。
- 动态结果使用持久的反馈 Label；不要每次点击都重复创建控件。
- 采用字符网格布局，使用 `getSize()` 做边界/居中计算，考虑小屏幕、长文本和空数据。
- 控件事件只负责协调 UI 与业务模块；磁盘、网络和数据逻辑放在独立模块。

## 事件与并发规则

- Basalt 使用协作式事件循环；`run`/自动更新模式、`onEvent`、`schedule` 共享事件处理生命周期。
- 事件回调保持短小，不在其中做无限循环、长时间计算或大批量同步 IO。
- 延迟流程优先用 `os.startTimer` + `timer` 事件；保存并比较 Timer ID，页面销毁/取消时使旧 ID 失效。
- 不把 `os.sleep` 当作后台线程；它会等待 CC 事件，具体对当前运行循环的影响按调用位置和目标构建实测。
- 网络 API 的阻塞性以当前 CC:Tweaked 版本和项目封装为准，不从“可靠传输”推断全部调度行为。

## 版本与验证

- 当前仓库存在最新版构建和 Basalt 2.5 备用实现；不要混用文档和代码假设。
- 文件大小只能作为构建差异线索，不能作为版本号。
- 如果 API 报 nil：先确认实际加载文件、版本、元素是否可用，再查该方法是否属于对应 widget。
- 修改后至少做 Lua 语法检查或最小运行测试；无法启动 CC 环境时，明确说明哪些内容仅完成静态检查。

## 后续 wiki Markdown 的融合规则

后续原始 Markdown 统一放入 [`docs/knowledge/basalt/wiki/`](../../docs/knowledge/basalt/wiki/)：

1. 原文只读保存，按 widget/主题命名；不同版本用后缀区分。
2. 从原文提炼到 `api/<widget>.md` 或 `api/<topic>.md`，记录创建方式、属性、事件、参数、返回值、版本、最小示例和来源。
3. 跨 widget 的稳定经验才进入 `patterns.md`。
4. 更新 `sources.md`；遇到 wiki、源码、项目示例冲突时保留冲突记录，不静默覆盖。
5. 不为每个 widget 创建一个 skill。一个 `basalt` skill 作为入口即可，知识库承载可增长的 API 资料。

## 输出要求

回答或修改 Basalt 代码时：

- 说明使用了哪个 Basalt 构建/版本假设。
- 给出可运行的最小示例，而不是只列函数名。
- 标出未验证的参数或版本差异。
- 完成代码审查时使用 [`docs/knowledge/basalt/patterns.md`](../../docs/knowledge/basalt/patterns.md) 的 checklist。
