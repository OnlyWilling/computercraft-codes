---
name: basalt-core-api
category: api-reference
version-target: repository-latest
status: partial
---

# Basalt 核心 API（当前仓库基准）

> 这不是对所有 widget 的完整翻译，而是从当前 Basalt Markdown 和仓库源码中能确认的核心用法。`verified` 表示源码或仓库示例确认；`example` 表示仓库项目实际调用过；`待验证` 表示应等对应 wiki 或最小运行测试。

## 1. 加载与启动

### `require("basalt")`

```lua
local basalt = require("basalt")
```

- 状态：`example`
- 作用：加载 Basalt API。
- 版本提示：当前项目同时存在 [`Basalt/basalt.lua`](../../../../Basalt/basalt.lua) 和 [`Basalt/basalt25.lua`](../../../../Basalt/basalt25.lua)，不要混用两套文档的假设。

### `basalt.createFrame(...)`

```lua
local frame = basalt.createFrame():setTitle("Bart Terminal")
```

- 状态：`example`；当前新版源码入口为 `createFrame`。
- 作用：创建根 Frame；默认使用当前 terminal，具体重定向/参数能力以目标构建为准。
- 仓库示例：[terminal.lua:259](../../../../bart/ui/terminal.lua#L259)、[admin.lua:307](../../../../bart/ui/admin.lua#L307)。

### `basalt.run()` / `basalt.autoUpdate()`

```lua
-- 阻塞式主循环：由 Basalt 接管事件循环
basalt.run()

-- 当前项目也使用自动更新模式
basalt.autoUpdate()
```

- `run`：`verified`，当前仓库的 2.5 源码实现会循环 `os.pullEventRaw()`、分发事件并绘制。
- `autoUpdate`：`example`，当前项目调用；在当前仓库可读的 `Basalt/basalt.lua` 主构建中未找到同名入口，因此它可能来自项目实际加载的另一份 Basalt 构建或兼容封装。使用前应确认 `require("basalt")` 的实际来源，并做最小运行测试。
- 设计建议：一个 UI 入口只选择一种生命周期模式；不要同时让多个代码路径各自启动 Basalt 主循环。

### `basalt.stop()`

```lua
basalt.stop()
```

- 状态：`verified`（当前仓库 Basalt 2.5 源码和新版构建均有实现）。
- 作用：请求停止 Basalt 运行循环；退出前是否清屏、是否清理子程序取决于构建版本。

## 2. Frame / Container 基本操作

### `frame:addLabel()`

```lua
frame:addLabel()
    :setPosition(3, 2)
    :setText("Title")
```

- 状态：`example`
- 常见用途：静态文本、状态信息、错误信息。
- 设计建议：动态结果使用单独的 Label，回调中只更新该 Label，而不是重复创建控件。

### `frame:addButton()` 与 `button:onClick(callback)`

```lua
frame:addButton()
    :setPosition(3, 5)
    :setSize(12, 1)
    :setText("Confirm")
    :onClick(function()
        -- 校验输入、更新状态、更新结果 Label
    end)
```

- 状态：`example`；当前仓库大量使用。
- 回调参数：项目示例既有无参数回调，也有接收 `self` 的形式；若需要修改按钮本身，使用 `function(self)`，否则使用无参数函数即可。
- 设计建议：点击回调先校验输入，再执行副作用；成功和失败都给用户明确反馈。

### `frame:addInput()`、`input:getText()`、`input:setInputType(type)`

```lua
local amount = frame:addInput()
    :setPosition(16, 5)
    :setSize(10, 1)
    :setInputType("number")

local value = tonumber(amount:getText()) or 0
```

- 状态：`example`
- 当前项目使用的输入类型：`"number"`；更多类型和限制等待 Input wiki 文档确认。
- 设计建议：UI 输入永远视为不可信字符串；在回调中显式转换、校验边界和空值。

### 链式调用

```lua
frame:addLabel():setPosition(3, 2):setSize(40, 1):setText("Status")
```

- 状态：`example`；当前仓库的控件 setter 返回元素自身。
- 适用：初始化阶段的短链式声明。
- 不适用：链条中混入复杂业务逻辑、过长表达式或需要复用控件的场景；此时保存局部变量更清晰。

### 几何与内容方法

| 方法 | 状态 | 用途 |
|---|---|---|
| `setPosition(x, y)` | `example` | 设置相对父容器的位置 |
| `setSize(width, height)` | `example` | 设置控件尺寸 |
| `setText(text)` | `example` | 设置文本 |
| `getText()` | `example` | 读取 Input 文本；其他 widget 是否支持需看其 API |
| `setBackground(color)` | `example` | 设置背景色 |
| `getSize()` | `example` | 读取 Frame 或元素尺寸 |
| `setTitle(text)` | `example` | 设置 Frame 标题 |
| `clear()` | `example` | 清除容器内容；具体是否重置所有属性需按目标版本确认 |
| `close()` | `example` | 关闭/隐藏当前 Frame 或 Dialog；具体语义按元素类型确认 |

## 3. 事件系统

### `basalt.onEvent(eventName, callback)`

```lua
basalt.onEvent("timer", function(timerID)
    -- 只处理属于本模块的 timer ID
end)
```

- 状态：`verified`（当前新版构建公开该入口；仓库已有文档示例）。
- 常见事件：`timer`、`key`、`key_up`、`char`、`rednet_message`；事件参数由 CC 事件和 Basalt 分发方式决定。
- 设计建议：回调应短小；复杂操作拆成状态转移函数或事件链。

### `basalt.schedule(function() ... end)`

```lua
basalt.schedule(function()
    while true do
        local event, timerID = os.pullEvent("timer")
        -- 处理 timerID
    end
end)
```

- 状态：`verified`（当前新版源码和 2.5 源码均有 schedule 实现）。
- 重要限定：`schedule` 是 Basalt 事件循环中的协作式 coroutine，不是抢占式线程。
- 推荐：让协程等待明确事件过滤器，或用 `os.startTimer` + 事件回调管理状态。
- 禁止：在事件回调中执行长时间计算、无限循环而不 yield、或使用未验证的阻塞网络调用。

### Timer 事件链

```lua
local steps = { step1, step2, step3 }
local index = 1
local timerID

local function advance()
    if index > #steps then return end
    steps[index]()
    index = index + 1
    if index <= #steps then
        timerID = os.startTimer(1)
    end
end

basalt.onEvent("timer", function(receivedID)
    if receivedID == timerID then
        advance()
    end
end)

advance()
```

- 状态：`example` / `patterns`
- 原则：Timer ID 必须保存并比较，避免多个 timer 相互误触发；页面销毁或流程取消时应使旧 ID 失效。

## 4. 属性系统与状态样式

当前 Markdown 描述了 `defineProperty` 会生成：

- `getXxx(value)`
- `setXxx(value)`
- `getXxxState(state)`
- `setXxxState(state, value)`

- 状态：`verified`，但这是 Basalt 内部/扩展元素作者使用的机制，不等同于每个应用 widget 都会暴露所有方法。
- 版本提示：状态方法依赖构建版本；使用前检查目标 `basalt.lua` 是否存在对应方法，不能仅凭文件大小判断。

## 5. 当前项目可复用页面结构

```lua
local function showPage(frame)
    frame:clear()

    local status = frame:addLabel()
        :setPosition(3, 2)
        :setSize(50, 3)
        :setText("")

    local input = frame:addInput()
        :setPosition(16, 6)
        :setSize(20, 1)

    frame:addButton()
        :setPosition(3, 8)
        :setSize(12, 1)
        :setText("Confirm")
        :onClick(function()
            local value = input:getText()
            if value == "" then
                status:setText("Please enter a value")
                status:setBackground(colors.red)
                return
            end
            status:setText("Success")
            status:setBackground(colors.green)
        end)
end
```

这套结构来自 [`bart/ui/terminal.lua`](../../../../bart/ui/terminal.lua) 和 [`bart/ui/admin.lua`](../../../../bart/ui/admin.lua)，是项目经验示例，不代表 Basalt 官方唯一写法。

## 6. 待收到 wiki 后补齐的 API

- 每个 widget 的创建方法、构造参数和默认尺寸。
- Button/Input/Label 的完整属性、状态、事件和返回值。
- Frame、Dialog、ScrollFrame、List、Table、TabControl、Slider 等组件。
- 布局、响应式、主题、动画、插件和 XML API。
- Basalt 最新版与 2.5 的逐项差异表。
