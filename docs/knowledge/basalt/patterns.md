---
name: basalt-ui-patterns
category: practice
version-target: repository-latest
---

# Basalt UI 设计与使用经验

## 1. 页面状态优先于控件堆叠

把页面看成“状态 + 渲染函数”：

- `showWaitCard(frame)`、`showCardInfo(frame, result)`、`showConsume(frame, result)` 是当前项目采用的页面切换方式。
- 进入页面时先 `frame:clear()`，再创建该页控件。
- 业务数据放在局部状态或模块状态中，控件只负责输入和展示。
- 返回、关闭、重试、取消都应有明确的状态转换，不要依赖用户重复点击碰运气。

## 2. 输入、校验、业务、副作用分层

按钮回调建议按固定顺序组织：

1. 读取输入：`input:getText()`。
2. 规范化：`tonumber`、去空格、默认值。
3. 校验：必填项、范围、枚举、当前业务状态。
4. 执行业务：调用磁盘、网络、成员等模块。
5. 持久化：保存成功后再显示成功消息。
6. 更新反馈：成功用清晰文本/颜色，失败说明下一步怎么处理。

当前 Bart 代码中的 `Confirm`、`Issue`、`Recharge` 回调都采用了这类结构。UI 层不应重复实现磁盘签名、会员升级或网络协议。

## 3. 反馈控件单独保存

不要在每次点击时重新创建一批状态 Label。页面初始化时创建一个 `resultLabel`，回调只调用 `setText`、`setBackground` 等更新方法。这样可以避免控件重复、布局漂移和旧消息残留。

## 4. 坐标布局与小屏适配

ComputerCraft UI 通常以字符网格为单位。当前项目采用显式坐标和递增 `y`：

```lua
local y = 2
frame:addLabel():setPosition(3, y):setText("Title")
y = y + 2
```

建议：

- 先确定最小目标屏幕尺寸，再放置控件。
- 给输入框、按钮和反馈文本预留足够宽度。
- 不要假设任意字符串都能在固定宽度内显示；必要时截断、换行或分页。
- 使用 `frame:getSize()` 做居中或边界计算。
- 复杂自适应布局应在收到 layout/responsive wiki 后再建立统一封装。

## 5. 事件循环与非阻塞

Basalt 和 CC:Tweaked 使用协作式事件模型。`basalt.run()` 会持续取事件、分发、绘制；`basalt.schedule` 运行在同一事件循环中。

实践规则：

- 事件回调保持短小，避免大批量扫描、深递归和长时间计算。
- 需要延迟的流程优先使用 `os.startTimer` + `timer` 事件，并保存 Timer ID。
- 页面切换或流程取消时，让旧 Timer 失效，避免过期回调修改新页面。
- `os.sleep` 在 CC 中会等待事件；它不是独立线程。是否会影响当前 Basalt 集成，取决于调用位置和运行循环，但在 UI 回调中不应把它当作后台并发机制。
- 网络函数是否阻塞，必须按 CC:Tweaked API 和项目封装实际实现验证；不要把“可靠”自动等同于“阻塞一切”。

## 6. 多窗口和外设终端

Basalt Frame 可以绑定 terminal/window/monitor，但不同构建的 `createFrame` 参数和终端绑定方式可能不同。使用前以目标构建 API 为准，并做最小测试：

1. 创建目标 terminal 或 window。
2. 创建 Frame 并绑定它。
3. 绘制一个 Label 和 Button。
4. 确认事件只到达预期 Frame。
5. 退出时恢复 `term.redirect`、清理窗口和外设状态。

仓库 [`Basalt/ui.lua`](../../../Basalt/ui.lua) 展示了 UI window、shell window、monitor frame 和 `Program` 元素并行工作的案例，但其中的并行和 `os.sleep` 行为不应直接复制到所有程序。具体来说，`parallel.waitForAny` 会并行推进多个协作式任务；某个任务等待事件时，其他任务仍可能运行，但长时间不让出执行权的代码仍会延迟整个程序。`os.sleep` 应按调用位置和目标运行时验证，而不是简单描述为“阻塞一切”。立即退出按钮中的等待也会延迟 `basalt.stop()`，应避免。

## 7. 版本纪律

- 先确认实际加载的是哪一个 `basalt.lua`。
- 不要因为某个版本有 `setXxxState`，就假设另一个版本也有。
- 官方 wiki 原文应保留版本信息；无版本信息的页面标为“版本未知”。
- 文档说法与源码冲突时，以可运行的目标版本为准，并在知识库记录冲突。

## 8. 代码审查清单

- [ ] 页面进入时是否清理旧控件或明确复用它们？
- [ ] 每个输入是否经过类型转换和边界校验？
- [ ] 成功消息是否只在业务和持久化都成功后显示？
- [ ] 失败路径是否保留可重试入口？
- [ ] 事件回调是否可能执行长时间工作？
- [ ] Timer ID 是否保存并校验？
- [ ] 是否依赖了当前 Basalt 构建不存在的方法？
- [ ] 小屏幕、长文本、空数据是否可用？
- [ ] 页面关闭时是否停止相关 Program、Timer、监听器或外设操作？
- [ ] 页面退出后是否恢复 terminal/window/monitor 状态？
