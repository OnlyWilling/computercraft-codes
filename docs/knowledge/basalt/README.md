---
name: basalt-knowledge
category: knowledge-index
version-target: repository-latest
---

# Basalt 知识库

本目录是 Basalt（Minecraft ComputerCraft / CC:Tweaked UI）资料的长期知识库。它把**原始资料、可检索 API、项目经验、版本差异**分开保存，避免把每一份 wiki Markdown 都堆进 skill。

## 当前基准

- 目标运行版本：仓库中的最新版构建 [`Basalt/basalt.lua`](../../../Basalt/basalt.lua)。
- 兼容参考：[`Basalt/basalt25.lua`](../../../Basalt/basalt25.lua)，文件内标注为 `2.5.0-dev`；它不是当前默认目标。
- 实际项目示例：[`bart/ui/terminal.lua`](../../../bart/ui/terminal.lua)、[`bart/ui/admin.lua`](../../../bart/ui/admin.lua)。
- 文件大小只能帮助发现“构建可能不同”，不能作为正式版本号；优先查看源码、构建信息和实际运行结果。

## 文档分层

| 文件/目录 | 作用 | 是否作为 API 事实来源 |
|---|---|---:|
| [`api/core.md`](api/core.md) | 从现有 Markdown 提取的核心 API，加上仓库代码验证结果 | 是，带来源标记 |
| [`patterns.md`](patterns.md) | UI 设计、事件处理、页面组织和项目经验 | 否，属于实践建议 |
| [`sources.md`](sources.md) | 资料来源、版本和可信度登记 | 用于追溯 |
| [`wiki/`](wiki/) | Basalt wiki 和本次迁移归档的原始 Markdown，只读保存 | 原始资料，需提炼后使用 |
| [`.claude/skills/basalt.md`](../../../.claude/skills/basalt.md) | 给开发代理使用的短入口、工作流和约束 | 不替代 API 文档 |

## 资料优先级

遇到冲突时按以下顺序判断：

1. 当前实际加载的 `basalt.lua` 和可运行的最小测试。
2. 同一版本的官方 wiki/API 文档。
3. 仓库内已经运行过的项目示例。
4. 旧版本示例、社区文章和未经验证的经验。

文档中的 API 应标注 `verified`（源码/最小测试确认）、`example`（项目代码使用过）或 `待验证`，不要把推测写成事实。

## 融合后续 wiki Markdown 的流程

1. 将原文件放入 [`wiki/`](wiki/)，文件名保留 widget 或主题名称，例如 `button.md`、`input.md`、`layout.md`。
2. 保留原文，不直接覆盖；如果同名文件来自不同 Basalt 版本，使用 `button-v2.md`、`button-latest.md` 等区分。
3. 提取公共结构到 `api/`：创建或更新对应主题文件，记录创建方法、属性 setter/getter、事件、参数、返回值、版本和最小示例。
4. 只有跨多个 widget、且对本项目反复有效的内容才写入 `patterns.md`；不要把某个 widget 的全部 API 复制到经验文档。
5. 更新 [`sources.md`](sources.md) 和本页目录；发现 API 与当前实现不符时，保留冲突说明并标记待验证。
6. skill 只增加“如何查找和应用知识”的规则。新增 widget 通常不需要新增 skill。

## 当前覆盖范围

目前已有资料覆盖：元素继承/属性系统、事件注册、`schedule`、timer 事件链、仓库中常用的 Frame/Label/Button/Input 基本调用，以及 CC 协作式事件循环的注意事项。

尚未有独立 wiki 原文支撑的内容：完整 widget 清单、每个 widget 的全部属性、布局系统、主题插件、响应式布局、图表/表格/列表等高级组件。收到对应 Markdown 后再逐项补齐，不以函数名猜测参数。
