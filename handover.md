# AEGIS-AUTOCRAFT 项目分析交接文档

> 分析日期：2026-08-05  
> 项目路径：`aegis-autocraft/`  
> 分析范围：4 个 startup.lua 文件的结构、功能、HTTP 使用、启动加载阶段详解

---

## 一、项目概况

基于 Minecraft ComputerCraft mod 开发的**综合自动化终端**，集成了**存储显示、自动合成、流体管理、矿车舰队监控**等功能。核心程序集中在 `computer/` 下，共 4 个 startup 文件。

---

## 二、四份 startup.lua 对比总览

| 文件 | 行数 | 角色 | 使用 HTTP？ | 说明 |
|---|---|---|---|---|
| `computer/startup.lua` | 11,494 行 | **主控终端（完整版）** | ✅ ntfy.sh + GitHub API | 带远程 rednet 控制支持 |
| `computer/src/startup.lua` | 12,290 行 | **主控终端（纯净版）** | ✅ ntfy.sh + GitHub API | 重构版，去掉远程控制模块 |
| `remote_control/startup.lua` | 433 行 | **矿车舰队远程监控面板** | ❌ | 通过 rednet 连接主控 |
| `turtle/startup.lua` | 51 行 | **合成龟脚本** | ❌ | 简单自动合成循环 |

### 2.1 核心关系图

```
remote_control/startup.lua          turtle/startup.lua
  (手持终端监控面板)                   (合成龟脚本)
         │ rednet                           │ 独立运行
         ▼
computer/startup.lua  (完整版，带远程接口)
  OR
computer/src/startup.lua (纯净版，无远程接口)
         │
         ▼
  工厂自动化核心：
  ├─ 配方管理（10个JSON文件）
  ├─ 自动合成引擎
  ├─ 自动补货系统
  ├─ 流体合成管道
  ├─ 机器管理
  ├─ GitHub同步/ntfy通知
  └─ 触摸显示器UI
```

### 2.2 computer/ 与 computer/src/ 的差异

`computer/startup.lua` 和 `computer/src/startup.lua` 功能上高度重叠，是同一程序的两个版本：

| 维度 | `computer/startup.lua` | `computer/src/startup.lua` |
|---|---|---|
| 代码风格 | 缩进不统一，风格较杂 | 4 空格统一缩进，更整洁 |
| 远程控制模块 | ✅ 有（`openRemoteLink`、`handleRemote`、`rednet.receive`） | ❌ 完全移除 |
| fluid 学习UI | 有（`drawFluidLearnUI`） | 有 |
| base64 编解码 | 有 | 有 |
| GitHub 同步 | 有 | 有 |
| ntfy 通知 | 有 | 有 |
| pendingTouches防抖 | 有 | 有 |
| 并行协程数 | 6 个（含 rednet 接收） | 5 个（无 rednet） |

**建议**：以 `src/startup.lua` 为基础进行后续开发（更干净，便于拆分）。

---

## 三、HTTP 使用分析

**只在两个 computer/ startup.lua 中使用，且仅限于两处：**

### 3.1 ntfy.sh 推送通知
- **用途**：合成完成/失败时推送手机通知
- **API**：`https://ntfy.sh/<topic>`，POST 请求
- **代码位置**：`src/startup.lua` 约第 3489-3530 行（`ntfyPublish`、`ntfyPollCommands`）
- 还支持从 ntfy 拉取命令（轮询待执行的远程命令，5 秒间隔）

### 3.2 GitHub API 同步
- **用途**：配方配置文件的导出/导入（通过 GitHub 仓库 base64 编解码传输）
- **API**：`https://api.github.com/repos/<owner>/<repo>/contents/<path>`
- **代码位置**：`src/startup.lua` 约第 3483-3930 行
- 需要配置 `github_repo` 和 `github_token`

**结论**：不是从网页下载第三方代码/依赖，是项目自身的数据同步和通知机制。

---

## 四、启动加载阶段详解

### 4.1 JSON 文件体系（10个）

所有文件存储在程序的**当前工作目录**下，文件名常量定义在第 1-11 行：

| 文件 | 存储内容 | Lua 变量 |
|---|---|---|
| `factory_recipes.json` | `{ "item_name": {配方对象}, ... }` | `Recipes` |
| `factory_config.json` | `{ storages: {...}, turtles: {...}, autostock_paused: bool }` | `Config` |
| `factory_autostock.json` | `{ "item_name": {threshold: N, target: N}, ... }` | `Autostock` |
| `factory_groups.json` | `{ "machine_name": true/false, ... }`（排除标记） | `ExcludedMachines` |
| `factory_alt_recipes.json` | `{ "item_name": [{配方},...], ... }` | `AltRecipes` |
| `factory_mgmt.json` | `[ {provider: bool, ...}, ... ]`（数组） | `MgmtGroups` |
| `factory_machine_labels.json` | `{ "peripheral_name": "label", ... }` | `MachineLabels` |
| `factory_custom_mg.json` | `[ {...}, ... ]`（数组） | `CustomMachineGroups` |
| `factory_fluids.json` | `{ "fluid_key": {配方对象}, ... }` | `FluidRecipes` |
| `factory_fluid_alts.json` | `{ "fluid_key": [{配方},...], ... }` | `FluidAltRecipes` |

配方对象典型结构（从 `findDuplicateRecipe` 反推）：

```lua
{
  type = "turtle",      -- 或 "crafting" / "create" / "fluid"
  machine_name = "me_drive",
  ingredients = { [1]="minecraft:iron_ingot", [2]="minecraft:stick", ... },
  output_device = "chest_1",               -- 可选
  imported = true,                          -- 可选：GitHub导入标记
}
```

### 4.2 启动加载流程

```
runMain()
  │
  ├─ ① 显示器初始化（第247行）
  │     monitor = peripheral.wrap("right")
  │
  ├─ ② initDataFiles()（第324行）→ 创建缺失的JSON文件
  │
  ├─ ③ loadData()（第346行）
  │     ├─ loadDataFile() 带备份恢复机制
  │     ├─ 兼容旧格式迁移
  │     └─ 加载所有 10 个文件到内存表
  │
  ├─ ④ syncFluidItemStubs()（第402行）
  │     └─ 流体配方产出物注册到 Recipes（type="fluid"）
  │
  └─ ⑤ parallel.waitForAny(...) → 启动 5 个并行协程
        ├─ monitor_touch 处理
        ├─ 键盘输入处理
        ├─ mainLoop（主UI/合成循环）
        ├─ mgmt传输协程（每10秒）
        └─ ntfy命令轮询（每5秒）
```

### 4.3 外设扫描系统

**无编号缓存**，使用字符串名称（如 `"left"`, `"chest_0"`）。

**扫描方法** `batchPeripheralScan(names, method, withSize)`（第528行）：

```
一次扫描流程：
Config.storages{ "left"=true, "top"=true, ... }
         │
         ▼ 提取外设名列表
   names = { "chest_0", "chest_1", ... }
         │
         ▼ batchPeripheralScan
   ┌──────────────────────────────┐
   │ 每批最多64个，并行扫描         │
   │ parallel.waitForAll(64个任务) │
   │   └─ peripheral.wrap(nm)     │
   │   └─ pcall(p.list())         │
   └──────────────────────────────┘
         │
         ▼ 返回 scaned[nm] = { data = list结果, size = size结果 }
```

### 4.4 缓存机制（内存表 + TTL）

| 缓存变量 | TTL | 存储内容 |
|---|---|---|
| `_stInvCache` | 4 秒 | `{inventory映射表, 总件数, 存储设备数, 空闲槽位, 总槽位}` |
| `_flInvCache` | 6 秒 | `{流体映射表, 储罐数, 总mB量, 储罐详情表}` |
| `_tankStatsCache` | 6 秒 | `{free=N, total=M}` |

`invalidateStockCache()` 在合成完成后调用，强制下次访问重新扫描。

---

## 五、后续研究建议

### 5.1 代码拆分建议

当前所有代码集中在单个 startup.lua 中，建议按模块拆分为独立文件：

```
src/
├── startup.lua           -- 入口，只保留初始化和主循环
├── config.lua            -- 配置文件管理
├── recipes.lua           -- 配方系统（加载、查找、计算）
├── craft_engine.lua      -- 合成引擎核心（calculateCraft, pushBatch 等）
├── fluid_craft.lua       -- 流体合成
├── autostock.lua         -- 自动补货
├── inventory.lua         -- 库存扫描与缓存
├── peripheral.lua        -- 外设扫描工具
├── machine_mgmt.lua      -- 机器管理与分组
├── ui/                   -- UI 模块
│   ├── main.lua          -- 主界面绘制
│   ├── draw_*.lua        -- 各标签页绘制函数
│   └── touch.lua         -- 触摸事件处理
├── network.lua           -- ntfy.sh + GitHub API
└── utils.lua             -- 工具函数
```

### 5.2 关键函数定位（src/startup.lua）

| 函数 | 行号 | 作用 |
|---|---|---|
| `initDataFiles()` | 324 | 创建默认 JSON 配置文件 |
| `loadData()` | 346 | 加载全部 JSON 到内存 |
| `loadDataFile(path)` | 262 | 单文件加载（含备份恢复） |
| `batchPeripheralScan()` | 528 | 批量并行外设扫描 |
| `getStorageInventory()` | 564 | 扫描存储外设获取物品库存 |
| `getFluidInventory()` | 660 | 扫描流体储罐获取流体库存 |
| `getStorageInventoryCached()` | 612 | 带缓存的物品库存查询 |
| `invalidateStockCache()` | 606 | 使缓存失效 |
| `calculateCraft()` | 1875 | **核心合成计算**：递归解析子配方 |
| `planProduction()` | 2103 | 生成生产计划 |
| `pushBatch()` | 1212 | 推送材料到合成机器 |
| `sweepCraftMachines()` | 875 | 扫描所有机器状态 |
| `ntfyPublish()` | 3525 | 发送推送通知 |
| `doGitExport()` | 3760 | 导出配方到 GitHub |
| `runMain()` | 12215 | 主入口函数 |
| `saveData()` | 435 | 保存所有配置到 JSON |
