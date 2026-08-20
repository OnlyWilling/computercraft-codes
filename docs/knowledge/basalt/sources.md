---
name: basalt-sources
category: provenance
---

# Basalt 资料来源登记

| 来源 | 类型 | 版本/状态 | 用途 |
|---|---|---|---|
| [`basalt.md`](../../../basalt.md) | 知识库兼容入口 | 当前入口 | 指向分层知识库 |
| [`wiki/basalt-notes-original.md`](wiki/basalt-notes-original.md) | 原始笔记归档 | 迁移前内容；已保留 | 追溯架构、属性、事件和并发经验的原始表述 |
| [`Basalt/basalt.lua`](../../../Basalt/basalt.lua) | 仓库实际构建 | 当前默认目标；minified | 核实核心入口、元素目录和属性机制 |
| [`Basalt/basalt25.lua`](../../../Basalt/basalt25.lua) | 仓库备用实现 | `2.5.0-dev` | 版本对照，不作为默认目标 |
| [`bart/ui/terminal.lua`](../../../bart/ui/terminal.lua) | 项目示例 | 实际使用 | 核实 Label/Button/Input/Frame 常用链式调用 |
| [`bart/ui/admin.lua`](../../../bart/ui/admin.lua) | 项目示例 | 实际使用 | 核实表单、校验、反馈和页面切换模式 |
| `docs/knowledge/basalt/wiki/` | 后续 wiki 原文 | 待添加 | 保留原始资料并追溯提取结果 |

## 当前文档的可信度规则

- **源码确认**：在目标 Basalt 构建中找到实现或公开注册点。
- **项目示例**：仓库中的代码实际调用过，但不代表完整 API 或跨版本兼容。
- **wiki 原文**：官方/社区资料的原始描述，必须保留版本上下文。
- **待验证**：仅由旧文档、函数名或推测得到；不能作为生成代码的唯一依据。

## 冲突记录

1. 原经验文档把 `os.sleep()` 概括为会阻塞“整个事件循环”。更准确的知识库表述是：它等待 CC 事件，并可能让当前协作式流程暂时不推进；实际影响取决于调用位置和 Basalt/CC 运行循环，不能替代实测。
2. 原经验文档建议用文件大小区分 Basalt 版本。文件大小可作为线索，但不是可靠版本标识；应优先使用构建源码、版本常量或最小运行测试。
3. 原经验文档将 `rednet.send` 概括为可靠且阻塞。网络行为应以当前 CC:Tweaked API 和 [`bart/lib/network.lua`](../../../bart/lib/network.lua) 的封装实现为准，不能仅凭该概括设计协议。
