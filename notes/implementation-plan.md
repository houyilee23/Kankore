# 艦これ改 任務追蹤器 — 實作計畫（本輪）

> 撰寫日期：2026-04-29  
> 最後更新：2026-04-30（Stage A~D 完成）  
> 適用版本：guide.html（目前 TASKS t001~t129）  
> 參考：`notes/feature-ideas.md`（A-1、C-1、C-2、E-1、D-2、F-1）

---

## 目前完成狀態

| Stage | 功能             | 狀態      | Commit    | 實際行數增量 |
|-------|-----------------|-----------|-----------|------------|
| A     | type badge + 篩選 | ✅ 已完成 | `be9f531` | 約 +160 行  |
| B     | 進度條           | ✅ 已完成 | `75c271c` | 約 +55 行   |
| C     | 路線規劃器       | ✅ 已完成 | `9b730aa` | 約 +150 行  |
| D     | 前置跳轉 badge   | ✅ 已完成 | `fd9b787` | +101 行     |
| E     | 艦娘需求清單     | ⏳ 待實作 | —         | 預估 +205 行 |

> guide.html 目前 **1447 行**（2026-04-30 量測，已含 Stage A~D）。  
> 所有變更已合併至 `main` 並部署到 GitHub Pages。

---

## 建議實作順序

```
Stage A → Stage B → Stage C → Stage D → Stage E
```

- **A → B**：A 補完 `type` 欄位後，B 的進度條不依賴 `type`，可平行但建議串行以避免合併衝突
- **B → C**：C 不依賴 A/B，但建議 A、B 先完成，避免每次改動都要重新測試整體 UI
- **C → D**：D（前置跳轉 badge）需要 C 的「前置路徑計算」概念打好後再做更流暢；但技術上 D 也可獨立做，只是 UI 互動邏輯較分散
- **E 最後**：E 需要補 `require_ships` 資料，資料補充工作量最大，放最後以免阻塞其他 Stage

---

## ✅ Stage A：任務種類 `type` 欄位 + 彩色 Badge + 種類篩選 Tab

> **完成**：commit `be9f531` `feat: add task type badges and category filter tabs`

### 1. 目標 / 範圍

為每個 task 節點加上任務種類標記（`type`），在任務卡片名稱旁顯示彩色 badge，並在頁面頂部的 Tab 列加入種類篩選功能（出撃 / 演習 / 遠征 / 工廠 / 改裝 / 編成 / 全部）。

### 2. 涉及修改的檔案區塊

| 區塊             | 修改內容                                                               |
|-----------------|------------------------------------------------------------------------|
| `<script>` TASKS | 在約 80 個 `kind:'task'` 物件上補 `type` 欄位                           |
| `<style>`        | 新增 `.type-badge` 及各 type 色彩變數；新增 `.tab.type-tab` 樣式         |
| HTML header      | 在 `.tabs` 區段新增第二排（或整合進現有 tabs）的種類篩選 Tab              |
| `<script>` 渲染  | 在 `renderTask()` 函數內插入 type badge 渲染；在 Tab 切換邏輯加入 type 篩選|

### 3. 新增 / 修改的資料欄位

新增 `type` 欄位到 TASKS 中每個 `kind:'task'` 物件：

```js
// 值域
type: 'sortie'       // 出撃（海域出擊）
type: 'exercise'     // 演習
type: 'expedition'   // 遠征
type: 'factory'      // 工廠（建造/開發/廢棄）
type: 'remodel'      // 改裝/改修
type: 'formation'    // 編成
```

`kind:'note'` 和 `kind:'reward'` 節點**不加** `type`。

### 4. 新增 / 修改的 localStorage key

無。`type` 是靜態資料，不需存 localStorage。

篩選狀態（目前選了哪個 type tab）用 JS 變數 `currentTypeFilter` 維持，不持久化（重整後回到「全部」即可）。

### 5. UI 草稿

**Badge 位置**：在任務卡片的 `.task-name` 前方，插入一個小 badge：

```
[ ⚓ 出撃 ]  はじめての「建造」！
[ 🚢 遠征 ]  中部西海域潜水艦哨戒を実施せよ！
[ 🔧 工廠 ]  機種転換
```

Badge 用 `<span class="type-badge type-sortie">⚓ 出撃</span>` 格式，圓角小膠囊樣式。

**Badge 色票（已加入 `:root`）**：

```css
--type-sortie: #e05555;       /* 出撃：紅 */
--type-exercise: #5ea0ef;     /* 演習：藍（沿用 --accent） */
--type-expedition: #4caf7d;   /* 遠征：綠 */
--type-factory: #9c7cd4;      /* 工廠：紫 */
--type-remodel: #e07b30;      /* 改裝：橘 */
--type-formation: #9aa0ab;    /* 編成：灰（沿用 --text-dim） */
```

**種類篩選 Tab**：在現有 `.tabs`（故事線篩選）下方新增第二排 `.tabs.type-tabs`：

```
[ 全部 ] [ ⚓ 出撃 ] [ 🎯 演習 ] [ 🚢 遠征 ] [ 🔧 工廠 ] [ ⚙ 改裝 ] [ 🗂 編成 ]
```

兩排 Tab 同時作用（AND 篩選）：故事線 Tab 選「D路線」、種類 Tab 選「遠征」→ 只顯示 D 路線的遠征任務。

### 6. 驗收標準

- [x] 每個 `kind:'task'` 節點在卡片名稱旁顯示對應顏色 badge
- [x] `kind:'note'` 和 `kind:'reward'` 節點不顯示 badge
- [x] 種類篩選 Tab 存在，點擊「出撃」後只顯示 `type:'sortie'` 的任務
- [x] 故事線 Tab + 種類 Tab 同時有效（AND 邏輯）
- [x] 點「全部」種類 Tab 時，行為與原本一致
- [x] 手機觸控 badge 不會觸發 checkbox 勾選（badge 僅展示，不可點擊）

### 7. 實際行數

約 +160 行（含 TASKS type 欄位補標 + CSS + JS）

---

## ✅ Stage B：進度條（全域 + 各路線）

> **完成**：commit `75c271c` `feat: add progress bars for global and per-route completion`

### 1. 目標 / 範圍

在 header 的進度計數（`XX / YY 完成`）旁加一條細進度條，視覺化完成百分比。同時在每個故事線分類的標題（bucket-header）旁顯示各路線進度（例如「D路線 8 / 14」）。

### 2. 涉及修改的檔案區塊

| 區塊         | 修改內容                                                                         |
|-------------|----------------------------------------------------------------------------------|
| `<style>`   | 新增 `.progress-bar-wrap`（全域）和 `.count-progress`（各路線）的樣式               |
| HTML header | 在 `h1` 下方插入 `<div class="progress-bar-wrap"><div class="progress-fill"></div></div>` |
| HTML main   | 在 `.bucket-header` 的 `.count` 改為 `.count-progress` 顯示 `X / Y` 格式          |
| JS 渲染     | `updateProgress()` 更新 `progress-fill` 寬度；`renderAll()` 計算各 cat 完成比例    |

### 3. 新增 / 修改的資料欄位

無。使用現有 `TASKS`、`kind`、`cat` 欄位和 localStorage 完成狀態。

### 4. 新增 / 修改的 localStorage key

無。

### 5. UI 草稿

**全域進度條**（header 內，`h1` 下方）：4px 細條，完成部分 `--done` 綠色，transition 平滑更新。

**各路線進度**（bucket-header 右側）：數字格式 `完成數 / 總數`（class `.count-progress`）。

### 6. 驗收標準

- [x] Header 顯示全域進度條，完成 0 任務時進度條為空，全部完成時為全滿
- [x] 進度條隨勾選/取消動作即時更新（不需重整頁面）
- [x] 每個故事線 bucket-header 顯示「X / Y」格式的各路線進度
- [x] 切換故事線 Tab 時，各路線進度顯示正確（計算基準永遠是全部任務）
- [x] 手機上進度條不會因為 safe-area 或字型差異而跑版

### 7. 實際行數

約 +55 行

---

## ✅ Stage C：最短完成路徑規劃器

> **完成**：commit `9b730aa` `feat: add shortest-path quest planner`

### 1. 目標 / 範圍

加入「路線規劃」功能：使用者從下拉選單選定一個目標任務（如 t017「Littorio」），系統計算出所有尚未完成的前置任務，用拓撲排序排列，顯示為「建議完成順序」清單。

### 2. 涉及修改的檔案區塊

| 區塊         | 修改內容                                                                              |
|-------------|--------------------------------------------------------------------------------------|
| `<style>`   | 新增 `#planner` 面板樣式；新增 `.planner-step`、`.planner-check`、`.step-*` 等樣式     |
| HTML header | 在 view-switch 按鈕列加入「🗺 規劃」按鈕                                               |
| HTML main   | 新增 `<section id="planner">` 面板，含目標 `<select>` 和結果 `<div id="planner-body">` |
| JS          | 新增 `buildAncestors()`、`topoSort()`、`plannerStepStatus()`、`renderPlanner()`、`populatePlannerSelect()` |

### 3. 新增 / 修改的資料欄位

無。使用現有 `prev`/`next` 欄位，透過 `effPrereqs()` 計算有效前置。

### 4. 新增 / 修改的 localStorage key

無。規劃結果是即時計算，不需持久化。

### 5. 實作細節（實際與規劃的差異）

- `buildAncestors(targetId)`：BFS 反向遍歷，支援 reward 節點（反查 `rewards` 欄位找 grantor task）
- `topoSort(nodeSet)`：Kahn's algorithm，未排到的節點 fallback 附加在末尾
- 規劃面板內 checkbox 可直接勾選，即時更新清單（透過 `plannerBody` 的 `change` 事件代理）
- 目標已達成時顯示「✅ 目標已達成」

### 6. 驗收標準

- [x] 頁面頂部有「規劃」按鈕，點擊後切換到規劃面板
- [x] 目標選單包含所有 `kind:'task'` 和 `kind:'reward'` 節點
- [x] 選定目標後，清單顯示所有前置任務（含已完成的，以劃線標示）
- [x] 清單依拓撲順序排列（可先做的排前面）
- [x] 清單中「可進行」任務高亮標示，旁邊顯示「← 從這裡開始」
- [x] 完成某個任務後（勾選 checkbox），規劃清單即時更新
- [x] 若目標任務已完成，顯示「✅ 目標已達成」提示
- [x] 切換回「清單」模式時，規劃面板隱藏

### 7. 實際行數

約 +150 行

---

## ✅ Stage D：前置任務跳轉 Badge

> **完成**：commit `fd9b787` `feat: add prerequisite jump badges on locked tasks`

### 1. 目標 / 範圍

強化現有的 `upcoming`（前置未完成）任務卡片：在卡片底部顯示可點擊的「🔒 [前置任務名稱]」badge，點擊後畫面滑動到該前置任務並高亮閃爍。

### 2. 涉及修改的檔案區塊

| 區塊       | 修改內容                                                                           |
|-----------|------------------------------------------------------------------------------------|
| `<style>` | 新增 `.prereq-badges`、`.prereq-badge`、`.prereq-more`、`.planner-jump`、`@keyframes task-flash`、`.task.flash` |
| JS 渲染   | 在 `renderTask()` 中，`kindClass === 'upcoming'` 時插入 `.prereq-badges` 區塊       |
| JS 函數   | 新增 `scrollToTaskFlash(id)`（scrollIntoView + flash animation）                    |

### 3. 新增 / 修改的資料欄位

無。使用現有 `prev` 欄位和 localStorage 完成狀態（透過 `effPrereqs()` 取有效前置）。

### 4. 新增 / 修改的 localStorage key

無。

### 5. 實作細節

- badge 只顯示 `kind:'task'` 且未完成的直接前置（排除 `note` 節點）
- 最多顯示 3 個，超過顯示 `+N 個前置`（class `.prereq-more`）
- 右側「📋 查看完整路線」（class `.planner-jump`）：`margin-left: auto` 靠右，點擊切換規劃面板並帶入該任務為目標
- `scrollToTaskFlash()`：切到 all 模式 → render → `setTimeout 50ms` → `scrollIntoView` → `void el.offsetWidth`（強制 reflow）→ 加 `.flash` → `setTimeout 1900ms` 後移除
- Flash animation：1.8s ease-out，從橘色底漸變回 `--panel`

### 6. 驗收標準

- [x] `upcoming` 狀態任務顯示未完成的直接前置 badge
- [x] `avail` 和 `done` 狀態任務不顯示前置 badge
- [x] 點擊 badge 後，頁面滑動到對應前置任務，且該任務卡片短暫高亮
- [x] 若有多個未完成前置，全部列出（最多 3 個，超過顯示「+N 個前置」）
- [x] 勾選某個前置任務後，對應的前置 badge 從 upcoming 任務卡片消失
- [x] 「📋 查看完整路線」連結跳規劃面板並自動帶入目標

### 7. 實際行數

+101 行（CSS ~48 行 + JS badge 渲染 ~37 行 + `scrollToTaskFlash` ~16 行）

---

## ⏳ Stage E：艦娘需求清單（待實作）

### 1. 目標 / 範圍

建立「所需艦娘」頁面：從 TASKS 的 `require_ships` 欄位（需先補充）彙整出全部需要的艦娘清單，使用者可勾選「我已持有」，系統自動計算哪些任務因缺少艦娘而受阻。

### 2. 涉及修改的檔案區塊

| 區塊             | 修改內容                                                                           |
|-----------------|------------------------------------------------------------------------------------|
| TASKS 資料       | 為需要特定艦娘的任務補上 `require_ships: ['翔鶴', '瑞鶴', ...]` 欄位（**最大資料工作量**）|
| `<style>`       | 新增 `#ships-panel` 面板樣式；`.ship-item` 樣式                                     |
| HTML            | 新增 `<section id="ships-panel">` 面板，含艦娘清單和持有勾選                          |
| JS              | 新增 `buildShipList()`（彙整所有 require_ships）、`renderShipsPanel()`、持有狀態讀寫邏輯 |

### 3. 新增 / 修改的資料欄位

新增 `require_ships: string[]` 欄位到需要特定艦娘的 task 物件：

```js
// 範例
{"id":"t007","name":"「第五航空戦隊」を再編成せよ！", ...,
  "require_ships": ["翔鶴","瑞鶴","朧","秋雲"]}
```

**資料補充工作**（Stage E 最大前置工作量，可分批完成）：
- 估計需補標約 40~50 個任務節點
- 來源：各任務的 `info` 欄位（已有非結構化艦娘名稱）和 wiki

### 4. 新增 / 修改的 localStorage key

新增 `kc_ships_v1`：

```js
// 格式：{ [shipName: string]: true }
// 未出現的艦名 = 未持有
localStorage.setItem('kc_ships_v1', JSON.stringify({ '翔鶴': true, '瑞鶴': true }));
```

### 5. UI 草稿

**觸發入口**：在頂部 view-switch 按鈕列加入「⚓ 艦娘」按鈕。

**艦娘面板**：

```
──── 艦娘持有清單 ────────────────────

[搜尋艦娘...]

🔴 未持有（影響 3 個任務）

  ☐ 翔鶴    → 影響：t007、t057、t094（3 個任務）
  ☐ 瑞鶴    → 影響：t007、t057、t094（3 個任務）
  ☐ 大和    → 影響：t107（1 個任務）

✅ 已持有

  ☑ 川内    → 影響：t049（1 個任務）
  ☑ 神通    → 影響：t049（1 個任務）

──── 影響任務總覽 ─────────────────────
缺少艦娘而受阻的任務：5 個
```

在任務清單中，因缺少艦娘而受阻的任務卡片顯示一個紅色 badge：`⚠ 缺 翔鶴`。

### 6. 驗收標準

- [ ] 「艦娘」面板存在，列出所有出現在 `require_ships` 中的艦娘
- [ ] 勾選「已持有」後，狀態存入 `kc_ships_v1`，重整後維持
- [ ] 勾選狀態改變後，任務清單中的「缺艦娘」warning badge 即時更新
- [ ] 未持有的艦娘列在前方，已持有的列在後方（或可切換排序）
- [ ] 每個艦娘顯示「影響幾個任務」及哪些任務 id

**手機驗收**：在 iOS Safari 打開，點「艦娘」，確認清單列出艦娘，勾選「翔鶴」後，任務清單中 t007 等任務的 warning badge 消失。

### 7. 預估

- 資料補標（`require_ships`）：約 +80 行 JSON 修改（分散在 TASKS 陣列），**工時最長**
- CSS（面板樣式）：約 +40 行
- HTML（面板結構）：約 +15 行
- JS（彙整 + 渲染 + 交叉比對）：約 +70 行
- **總計：約 +205 行**，預估工時 3 小時（含資料補標）

### 8. 依賴關係

- 技術上不依賴其他 Stage，但資料補標工作量大，建議放最後
- 可先做 UI 骨架（view-switch 按鈕 + 空面板），之後補 `require_ships` 欄位

### 9. 下個 session 的起點

1. 閱讀 `CLAUDE.md`（架構約束）和本文件（目前完成狀態）
2. 確認 `guide.html` 當前行數（目前 1447 行，Stage E 完成後預估 ~1650 行）
3. 從補標 `require_ships` 資料開始，或先搭 UI 骨架再回來補資料

---

## 整體規模（更新）

| Stage | 功能             | 狀態      | 實際行數增量 | Commit    |
|-------|-----------------|-----------|------------|-----------|
| A     | type badge + 篩選 | ✅ 完成  | 約 +160 行 | `be9f531` |
| B     | 進度條           | ✅ 完成  | 約 +55 行  | `75c271c` |
| C     | 路線規劃器       | ✅ 完成  | 約 +150 行 | `9b730aa` |
| D     | 前置跳轉 badge   | ✅ 完成  | +101 行    | `fd9b787` |
| E     | 艦娘需求清單     | ⏳ 待實作 | 預估 +205 行 | —       |

> guide.html 目前 **1447 行**（Stage A~D 完成後）。Stage E 完成後預估約 **1650 行**。  
> 所有已完成的變更均在 `main` 分支，已部署至 GitHub Pages（repo: `houyilee23/Kankore`）。

---

## Commit 記錄

```
fd9b787  feat: add prerequisite jump badges on locked tasks   ← Stage D
9b730aa  feat: add shortest-path quest planner               ← Stage C
75c271c  feat: add per-category progress bars                ← Stage B
be9f531  feat: add task type badges and category filter tabs  ← Stage A
9876ff4  docs: add CLAUDE.md and implementation plan
00a875a  Initial commit: Kankore quest tracker guide.html
```

---

*本文件供 Claude Code session 自動讀取，記錄實作進度與技術細節。*
