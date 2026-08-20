---
name: basalt-notes-original
source: repository-basalt-md
category: source-archive
status: migrated-reference
---

# Basalt GUI 开发指南

> 迁移参考：本文件保留迁移前根目录 `basalt.md` 的章节结构和主要内容，并对已确认的绝对化版本/并发表述做了限定。它包含项目经验和社区资料混合内容；使用时以 [`sources.md`](../sources.md) 的可信度规则为准。后续修订请写入 `api/` 或 `patterns.md`，不要直接修改本归档。

## 一、Basalt 架构核心

### 1.1 元素系统（Element System）

所有 UI 元素继承自 `VisualElement` → `Container` → `BaseElement`。每个元素类通过 metatable 实现继承：

```lua
local VisualElement = aa.getElement("VisualElement")
local Button = setmetatable({}, VisualElement)  -- Button 继承 VisualElement
Button.__index = Button                         -- 实例的 __index 指向类表
```

**实例方法查找链**：`instance → instance.__index(=class) → class's metatable(=parent class) → ...`

这意味着子类可以调用父类定义的所有方法。

### 1.2 Property 系统

`defineProperty` 为每个属性自动生成四个方法：

```lua
aa.defineProperty(aa, "background", {default=colors.black, type="color"})
-- 自动生成：
--   element:setBackground(value)         → 设置属性
--   element:getBackground()              → 读取属性
--   element:setBackgroundState(state, v) → 设置状态样式
--   element:getBackgroundState(state)    → 读取状态样式
```

其中 `setXxxState` / `getXxxState` 是部分新版 Basalt 构建才有的功能；不能仅根据文件大小判断版本，应以实际加载的构建和源码为准。

### 1.3 Z 轴层级

```lua
element:setZ(number)
```

- 数字越大通常越靠顶层；具体命中和渲染顺序应以目标构建确认。
- 原始笔记记录的默认值：Button=5, Label=3, Frame/其他=1；这不是跨版本保证。

### 1.4 事件系统

```lua
basalt.onEvent("rednet_message", function(senderID, msg, protocol) ... end)
basalt.onEvent("key", function(key) ... end)
basalt.onEvent("timer", function(timerID) ... end)
basalt.onEvent("char", function(char) ... end)

basalt.schedule(function()
    while true do
        -- 通过事件或 timer 主动让出执行权
        local event = os.pullEvent()
        -- 定时任务
    end
end)
```

## 二、CC/Basalt 并发模型

CC:Tweaked 使用协作式 coroutine。`os.sleep()` 和 `os.pullEvent()` 会让出当前协程并等待事件；它们不是独立线程。等待期间，其他任务能否继续运行取决于事件循环、任务调度方式和调用位置。不要在 UI 回调中把它们当作后台并发机制，也不要在回调中执行长时间计算。

可靠网络调用的阻塞性必须按当前 CC:Tweaked 版本和项目封装实测，不能仅凭“可靠”二字推断整个 Basalt 事件循环都会停止。

## 三、事件驱动模式

### 3.1 用 Timer 管理延迟步骤

```lua
local steps = {step1, step2, step3}
local stepIndex = 1
local turnTimer

local function advanceStep(room)
    if stepIndex > #steps then return end
    steps[stepIndex](room)
    stepIndex = stepIndex + 1
    if stepIndex <= #steps then
        turnTimer = os.startTimer(1)
    end
end

basalt.onEvent("timer", function(timerID)
    if turnTimer == timerID then
        advanceStep(room)
    end
end)
```

Timer ID 应保存、比较；流程取消或页面销毁时应使旧 ID 失效。

### 3.2 递归改事件链

```lua
local function processNext(room)
    local rs = room.state
    if #rs.turnCards == 0 then
        finishTurn(room)
        return
    end
    process(rs.turnCards[1], room)
    table.remove(rs.turnCards, 1)
    if #rs.turnCards > 0 then
        rs.phase = "RESOLVING"
        rs.turnTimer = os.startTimer(1)
    else
        finishTurn(room)
    end
end
```

## 四、网络游戏模式

| 方法 | 用途 | 说明 |
|---|---|---|
| `rednet.broadcast(msg, proto)` | 广播状态、心跳 | 是否可靠、是否丢包由网络环境决定 |
| `rednet.send(receiver, msg, proto)` | 发送给指定计算机 | 可靠性、等待行为和超时按当前 CC:Tweaked 版本确认 |
| `rednet.lookup(proto, hostname)` | 服务发现 | 使用前确认 modem、协议和返回值 |

如果采用广播模拟定向消息，应在消息中加入目标字段，并在接收方严格过滤；敏感数据不能因为广播而默认安全。

## 五、常见问题与排查

### 5.1 `attempt to call a nil value` on Basalt methods

可能原因包括：加载了不同版本的 `basalt.lua`、方法属于其他 widget/插件、元素未加载，或 API 名称与目标版本不一致。解决：确认实际加载路径和构建版本，再查源码、wiki 和最小测试。

### 5.2 LSP 报语法错误但运行正常

minified Basalt 文件的长行可能影响编辑器体验。应使用可读源码、独立类型/接口说明或最小测试辅助判断，不要无条件忽略所有 LSP 报错。

### 5.3 事件队列积压

- `basalt.schedule` 协程共享事件处理生命周期。
- 频繁 UI 更新、密集计算和同步 IO 可能延迟其他事件。
- 关键超时建议保存实际时间戳，例如 `os.clock()`，并结合目标环境验证其语义。
- 事件处理器中避免密集计算或大量 UI 操作。

## 六、开发工作流建议

### 6.1 代码验证 checklist

- [ ] 是否确认实际加载的 Basalt 构建和版本？
- [ ] 是否查过目标 widget 的公开 API，而非猜测方法？
- [ ] 每个输入是否经过类型转换和边界校验？
- [ ] 延迟流程是否保存并校验 Timer ID？
- [ ] 事件回调和 schedule 是否会执行长时间工作？
- [ ] 页面切换、关闭和重试是否有明确状态？
- [ ] 小屏幕、长文本、空数据是否可用？
- [ ] 网络行为是否按当前 CC:Tweaked API 和项目封装确认？

### 6.2 调试技巧

- 用 `os.clock()` 或目标环境提供的时间 API 埋点测量耗时。
- 在 CC 电脑上可以用 `term.write()` 直接输出到屏幕辅助调试。
- 只在目标构建支持且确实启用时使用 Basalt debug 插件。
