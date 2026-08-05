---
name: basalt
description: Basalt GUI 库（CraftOS- PC/CC:Tweaked）开发指南与最佳实践
---

# Basalt GUI 开发指南

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

其中 **`setXxxState`** 是新版 Basalt（298KB minified build）才有的功能，旧版（225KB）不生成此方法。

> ⚠️ 版本区别：新版 Basalt 的 `defineProperty` 包含 `setXxxState` / `getXxxState`，旧版只有 `setXxx` / `getXxx`。使用时根据文件大小确认 basalt.lua 是哪个版本。

### 1.3 Z 轴层级

```lua
element:setZ(number)
```

- **数字越大 = 越靠顶层**（在父容器中后渲染）
- 默认值：Button=5, Label=3, Frame/其他=1

### 1.4 事件系统

```lua
basalt.onEvent("rednet_message", function(senderID, msg, protocol) ... end)
basalt.onEvent("key", function(key) ... end)
basalt.onEvent("timer", function(timerID) ... end)
basalt.onEvent("char", function(char) ... end)

-- 在后台协程中执行循环任务
basalt.schedule(function()
    while true do
        os.sleep(5)
        -- 定时任务
    end
end)
```

---

## 二、⚠️ CC/Basalt 并发模型（最重要）

**这是最容易被误解的部分，也是绝大多数 Bug 的根源。**

### 2.1 `os.sleep()` 阻塞一切

CC 的协程是**协作式**的，`os.sleep()` 内部调用 `os.pullEvent()`，**会阻塞整个计算机的事件循环**，包括：

- 其他 `basalt.schedule` 协程（如心跳）
- UI 渲染更新
- `basalt.onEvent` 注册的回调处理

```lua
-- ❌ 错误：这会阻塞所有其他协程
basalt.schedule(function()
    while true do
        os.sleep(1)  -- 整个事件循环卡住 1 秒
        -- 处理游戏逻辑
    end
end)

-- ✅ 正确：使用 os.startTimer + 事件回调
-- (见下文"事件驱动模式")
```

### 2.2 `rednet.send()` 也阻塞

`rednet.send(receiver, msg, protocol)` 是可靠传输模式，内部等待 ACK，**会阻塞直到接收方确认或超时**。阻塞期间：

- 心跳协程无法运行
- 无法发送任何 broadcast
- 其他房间的处理也被卡住

```lua
-- ❌ 错误：阻塞所有处理
for _, pid in ipairs(players) do
    rednet.send(pid, { type = "private_data", data = secret }, PROTOCOL)
end

-- ✅ 正确：用 broadcast + targetID 替代
for _, pid in ipairs(players) do
    rednet.broadcast({ type = "private_data", data = secret, targetID = pid }, PROTOCOL)
end
```

### 2.3 核心原则

> **任何 `os.sleep()`、`rednet.send()`（可靠模式）、`os.pullEvent()` 都会阻塞整个事件循环。需要等待的操作必须用 `os.startTimer` + 事件回调实现。**

---

## 三、事件驱动模式（替代阻塞）

### 3.1 用 Timer 替代 sleep

```lua
-- ❌ 阻塞版
local function doThings()
    step1()
    os.sleep(1)
    step2()
    os.sleep(1)
    step3()
end

-- ✅ 事件驱动版
local steps = {step1, step2, step3}
local stepIndex = 1

local function advanceStep(room)
    if stepIndex > #steps then return end
    steps[stepIndex](room)
    stepIndex = stepIndex + 1
    if stepIndex <= #steps then
        room.state.turnTimer = os.startTimer(1)  -- 非阻塞等待
    end
end

-- Timer 处理器中：
basalt.onEvent("timer", function(timerID)
    if room.state.turnTimer == timerID then
        advanceStep(room)
    end
end)
```

### 3.2 递归改事件链

```lua
-- ❌ 递归阻塞版
local function resolveAll(items, room)
    if #items == 0 then return end
    process(items[1], room)
    table.remove(items, 1)
    sleep(1)
    resolveAll(items, room)  -- 递归阻塞
end

-- ✅ 事件链版
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
        rs.turnTimer = os.startTimer(1)  -- 继续下一张
    else
        finishTurn(room)
    end
end
```

---

## 四、网络游戏模式

### 4.1 rednet 通信模式

| 方法 | 可靠性 | 是否阻塞 | 用途 |
|------|--------|---------|------|
| `rednet.broadcast(msg, proto)` | 不可靠 | **否** ✅ | 游戏状态广播、心跳 |
| `rednet.send(receiver, msg, proto)` | 可靠 | **是** ❌ | 避免使用 |
| `rednet.lookup(proto, hostname)` | - | 否 | 服务发现 |

**原则**：所有消息都用 broadcast，需要点对点时加 `targetID` 字段让客户端自行过滤。

---

## 五、常见问题与排查

### 5.1 "attempt to call a nil value" on basalt methods

**原因**：加载了旧版（225KB）basalt.lua，缺少 `setXxxState` 等方法。
**解决**：确认 basalt.lua 为 298KB 的新版 production build（包含 `setPropertyState` / `getPropertyState`）。

### 5.2 LSP 报 "Unexpected symbol" 但语法正确

**原因**：minified basalt.lua 中的长行或特殊语法结构导致 LSP 解析偏差。
**解决**：以实际运行测试为准，LSP 警告可能是误报。

### 5.3 事件队列积压的影响

- Basalt 的 `basalt.schedule` 协程共享同一个事件循环
- 频繁的 UI 更新（如每秒刷新）可能延迟其他事件处理
- 关键检测（心跳超时、game timer）应使用 `os.clock()`（wall-clock）而非事件计数
- 事件处理器中应避免密集计算或大量 UI 操作

---

## 六、开发工作流建议

### 6.1 代码验证 checklist

- [ ] 所有 `sleep()` 是否可以用 timer 替代？
- [ ] 所有 `rednet.send` 是否可以用 `rednet.broadcast` + targetID 替代？
- [ ] 心跳超时阈值是否覆盖了最大阻塞时间？
- [ ] basalt.lua 版本是否一致（新版 298KB）？
- [ ] basalt.schedule 协程中是否有阻塞调用？

### 6.2 调试技巧

- 用 `os.clock()` 埋点测量阻塞时间：
  ```lua
  local t = os.clock()
  rednet.send(...)
  NIMMT_LOG(nil, "Log", "rednet.send took " .. (os.clock() - t) .. "s")
  ```
- 在 CC 电脑上可以用 `term.write()` 直接输出到屏幕辅助调试
- 启用 basalt debug 插件（如果可用）
