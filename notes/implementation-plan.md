# 艦これ改 任務追蹤器 — 實作計畫（本輪）

> 撰寫日期：2026-04-29  
> 適用版本：guide.html（目前 TASKS t001~t129）  
> 參考：`notes/feature-ideas.md`（A-1、C-1、C-2、E-1、D-2、F-1）

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

## Stage A：任務種類 `type` 欄位 + 彩色 Badge + 種類篩選 Tab

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

篩選狀態（目前選了哪個 type tab）建議用 JS 變數 `currentTypeFilter` 維持，不持久化（重整後回到「全部」即可）。

### 5. UI 草稿

**Badge 位置**：在任務卡片的 `.task-name` 前方，插入一個小 badge：

```
[ ⚓ 出撃 ]  はじめての「建造」！
[ 🚢 遠征 ]  中部西海域潜水艦哨戒を実施せよ！
[ 🔧 工廠 ]  機種転換
```

Badge 用 `<span class="type-badge type-sortie">⚓ 出撃</span>` 格式，圓角小膠囊樣式。

**Badge 色票（新增至 `:root`）**：

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

- [ ] 每個 `kind:'task'` 節點在卡片名稱旁顯示對應顏色 badge
- [ ] `kind:'note'` 和 `kind:'reward'` 節點不顯示 badge
- [ ] 種類篩選 Tab 存在，點擊「出撃」後只顯示 `type:'sortie'` 的任務
- [ ] 故事線 Tab + 種類 Tab 同時有效（AND 邏輯）
- [ ] 點「全部」種類 Tab 時，行為與原本一致
- [ ] 手機觸控 badge 不會觸發 checkbox 勾選（badge 僅展示，不可點擊）

**手機驗收**：在 iOS Safari 打開 guide.html，點頂部「出撃」Tab，確認只剩出擊任務，每張卡片都有紅色「⚓ 出撃」badge。

### 7. 預估

- 資料補標（`type` 欄位）：約 +80 行 JSON 修改（分散在 TASKS 陣列）
- CSS（badge 樣式 + tab 樣式）：約 +40 行
- HTML（Tab 列）：約 +10 行
- JS（渲染 + 篩選邏輯）：約 +30 行
- **總計：約 +160 行**，預估工時 1.5 小時

### 8. 依賴關係

- 無前置依賴，Stage A 可獨立開始
- Stage C-1（種類篩選 Tab）依賴本 Stage 的 `type` 欄位

---

## Stage B：進度條（全域 + 各路線）

### 1. 目標 / 範圍

在 header 的進度計數（`XX / YY 完成`）旁加一條細進度條，視覺化完成百分比。同時在每個故事線分類的標題（bucket-header）旁顯示各路線進度（例如「D路線 8 / 14」）。

### 2. 涉及修改的檔案區塊

| 區塊         | 修改內容                                                                         |
|-------------|----------------------------------------------------------------------------------|
| `<style>`   | 新增 `.progress-bar`（全域）和 `.bucket-progress`（各路線）的樣式                   |
| HTML header | 在 `.progress` span 旁插入 `<div class="progress-bar"><div class="progress-fill"></div></div>` |
| HTML main   | 在 `.bucket-header` 的 `.count` 旁加入 `<span class="bucket-progress">X/Y</span>` |
| JS 渲染     | 更新 `renderAll()` 或等效函數，計算各 bucket 的完成比例，用 `style.width` 動態設定  |

### 3. 新增 / 修改的資料欄位

無。使用現有 `TASKS`、`kind`、`cat` 欄位和 localStorage 完成狀態。

### 4. 新增 / 修改的 localStorage key

無。

### 5. UI 草稿

**全域進度條**（header 內，`h1` 下方）：

```
艦これ 任務追蹤                              43 / 86 完成
[============================--------]   50%
```

細長條（高度 4px），完成部分用 `--done`（綠色），未完成部分用 `--border`（暗灰）。

**各路線進度**（bucket-header 右側，取代或補充現有 count badge）：

```
主線/支線                                    23 / 45
D: Littorio 入手                              8 / 14
E: Z1 入手                                    5 / 11
```

count badge 保留原有樣式，旁邊不加進度條（手機空間不夠），僅更新數字格式為 `完成數 / 總數`。

### 6. 驗收標準

- [ ] Header 顯示全域進度條，完成 0 任務時進度條為空，全部完成時為全滿
- [ ] 進度條隨勾選/取消動作即時更新（不需重整頁面）
- [ ] 每個故事線 bucket-header 顯示「X / Y」格式的各路線進度
- [ ] 切換故事線 Tab 時，各路線進度顯示正確（篩選不影響計算基準，計算基準永遠是全部任務）
- [ ] 手機上進度條不會因為 safe-area 或字型差異而跑版

**手機驗收**：在 iOS Safari 打開 guide.html，勾選幾個任務，觀察 header 進度條增長，再看各 bucket-header 的數字對應正確。

### 7. 預估

- CSS（進度條樣式）：約 +25 行
- HTML（進度條 + bucket 數字）：約 +10 行
- JS（計算 + 更新邏輯）：約 +20 行
- **總計：約 +55 行**，預估工時 1 小時

### 8. 依賴關係

- 無前置依賴，Stage B 可獨立開始，與 Stage A 不衝突
- 建議在 Stage A 完成後才做，避免同一份 TASKS 陣列同時被多處修改

---

## Stage C：最短完成路徑規劃器

### 1. 目標 / 範圍

加入「路線規劃」功能：使用者從下拉選單（或搜尋）選定一個目標任務（如 t017「Littorio」），系統計算出所有尚未完成的前置任務，用拓撲排序排列，顯示為「建議完成順序」清單。

### 2. 涉及修改的檔案區塊

| 區塊         | 修改內容                                                                              |
|-------------|--------------------------------------------------------------------------------------|
| `<style>`   | 新增 `#planner` 面板樣式（overlay 或獨立 section）；新增 `.planner-step` 樣式           |
| HTML header | 在 view-switch 按鈕列加入「🗺 規劃」按鈕，切換顯示規劃面板                               |
| HTML main   | 新增 `<section id="planner">` 面板，含目標選擇 `<select>` 和結果列表 `<ol id="planner-steps">` |
| JS          | 新增 `buildAncestors(targetId)`（BFS 反向遍歷）、`topoSort(nodeSet)`（拓撲排序）、`renderPlanner()` 函數 |

### 3. 新增 / 修改的資料欄位

無。使用現有 `prev`/`next` 建立反向 adjacency map。

需要在 JS 初始化時建立：
```js
const PREV_MAP = Object.fromEntries(TASKS.map(t => [t.id, t.prev ?? []]));
```
（`TASKS_BY_ID` 已存在可複用）

### 4. 新增 / 修改的 localStorage key

無。規劃結果是即時計算，不需持久化。

### 5. UI 草稿

**觸發入口**：在頂部 view-switch 按鈕列（`[ 清單 ] [ DAG ]`）加入第三個按鈕 `[ 🗺 規劃 ]`。

**規劃面板**（替換 `<main>` 的內容顯示，或 overlay）：

```
──── 路線規劃 ────────────────────────

目標任務：[  Littorio（t017）      ▼ ]

建議完成順序（還差 6 步）：

  1. ✅ t010  はじめての「編成」！          已完成
  2. ✅ t027  「駆逐隊」を編成せよ！        已完成
  3. 🔵 t030  「水雷戦隊」を編成せよ！      可進行  ← 今天從這裡開始
  4. 🟡 t035  大規模艦隊を編成せよ！        待解鎖
  5. 🟡 t040  「水上機母艦」を配備せよ！    待解鎖
  6. 🟡 t042  「第六駆逐隊」を編成せよ！   待解鎖
  ...

──── 共需完成 N 個前置任務 ────────────
```

顏色規則：
- ✅ 綠色：已完成（劃線或 dim）
- 🔵 藍色（`--avail`）：當前可進行（所有 prev 均已完成）
- 🟡 橘色（`--upcoming`）：尚有未完成的前置

目標選單只列出 `kind:'task'` 且 `kind:'reward'` 的節點（reward 節點作為里程碑目標很直覺，如「Littorio」、「Z1」）。

**「從這裡開始」箭頭**：高亮第一個狀態為「可進行」（`--avail`）的任務，旁邊顯示「← 今天從這裡開始」提示文字。

### 6. 驗收標準

- [ ] 頁面頂部有「規劃」按鈕，點擊後切換到規劃面板
- [ ] 目標選單包含所有 `kind:'task'` 和 `kind:'reward'` 節點，可搜尋/捲動
- [ ] 選定目標後，清單顯示所有前置任務（含已完成的，以劃線標示）
- [ ] 清單依「可先做的排前面」的拓撲順序排列
- [ ] 清單中「可進行」任務高亮標示，是目前沒有任何未完成前置的任務
- [ ] 完成某個任務後（勾選 checkbox），規劃清單即時更新（不需重開規劃面板）
- [ ] 若目標任務已完成，顯示「✅ 目標已達成」提示
- [ ] 切換回「清單」模式時，規劃面板隱藏

**手機驗收**：在 iOS Safari 打開，點「規劃」，選擇「Littorio」，確認列出的任務順序合理，第一個可進行的任務與目前 DAG 狀態吻合。

### 7. 預估

- CSS（面板樣式）：約 +50 行
- HTML（面板結構）：約 +20 行
- JS（BFS + 拓撲排序 + 渲染）：約 +80 行
- **總計：約 +150 行**，預估工時 2 小時

### 8. 依賴關係

- 技術上不依賴 Stage A 或 B，但建議在 A、B 完成後做
- Stage D（前置任務跳轉 badge）建議在本 Stage 完成後實作，可複用 `buildAncestors()` 邏輯

---

## Stage D：前置任務跳轉 Badge（依賴 Stage C 完成後）

### 1. 目標 / 範圍

強化現有的 `upcoming`（前置未完成）任務卡片：在卡片底部顯示「還需完成前置：[任務名稱]」的可點擊 badge，點擊後畫面滑動到該前置任務。

### 2. 涉及修改的檔案區塊

| 區塊       | 修改內容                                                                          |
|-----------|-----------------------------------------------------------------------------------|
| `<style>` | 新增 `.prereq-badge`（可點擊跳轉樣式，底線或箭頭圖示）                              |
| JS 渲染   | 在 `renderTask()` 中，當任務狀態為 `upcoming` 時，插入 `.prereq-badge` 列表；加入點擊跳轉邏輯 |

### 3. 新增 / 修改的資料欄位

無。使用現有 `prev` 欄位和 localStorage 完成狀態。

### 4. 新增 / 修改的 localStorage key

無。

### 5. UI 草稿

在 `upcoming` 任務卡片的展開區域（或即使未展開的卡片底部），插入：

```
[ 🔒 需先完成：「水雷戦隊」を編成せよ！ (t030) → ]
[ 🔒 需先完成：「砲撃演習」を継続実施せよ！ (t021) → ]
```

Badge 樣式：橘色文字（`--upcoming`）、底線、手形 cursor、點擊後 `scrollIntoView` 到對應任務卡片，並短暫高亮（0.5s flash animation）。

只顯示**直接前置**（`prev` 陣列中尚未完成的任務），不遞迴顯示全部祖先（避免資訊爆炸）。

Stage C 完成後，可在這裡加一個「📋 查看完整路線」連結，直接跳到規劃面板並自動帶入此任務為目標。

### 6. 驗收標準

- [ ] `upcoming` 狀態任務顯示未完成的直接前置 badge
- [ ] `avail` 和 `done` 狀態任務不顯示前置 badge
- [ ] 點擊 badge 後，頁面滑動到對應前置任務，且該任務卡片短暫高亮
- [ ] 若有多個未完成前置，全部列出（最多顯示 3 個，超過顯示「+N 個前置」）
- [ ] 勾選某個前置任務後，對應的前置 badge 從 upcoming 任務卡片消失

**手機驗收**：在 iOS Safari 打開，找到一個 `upcoming`（橘色）任務，確認底部有前置跳轉 badge，點擊後畫面跳到對應任務並閃爍。

### 7. 預估

- CSS（badge + flash animation）：約 +25 行
- JS（渲染 + scrollIntoView + flash）：約 +30 行
- **總計：約 +55 行**，預估工時 45 分鐘

### 8. 依賴關係

- 建議在 Stage C 完成後進行（可複用 Stage C 的「前置計算」概念，並加入「查看完整路線」連結）
- 技術上可在 Stage A/B 完成後就獨立做，不強制依賴 C

---

## Stage E：艦娘需求清單

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
- 若要求 `require_ships` 資料完整才啟動 UI，可先做 UI 骨架（從 `info` 文字 fallback 解析），之後補上結構化欄位

---

## 整體規模估算

| Stage | 功能             | 預估行數增量 | 預估工時 | 依賴       |
|-------|-----------------|------------|---------|------------|
| A     | type badge + 篩選 | +160 行    | 1.5 小時 | 無         |
| B     | 進度條           | +55 行     | 1 小時   | 無         |
| C     | 路線規劃器       | +150 行    | 2 小時   | 無（建議 A 後）|
| D     | 前置跳轉 badge   | +55 行     | 45 分鐘  | 建議 C 後  |
| E     | 艦娘需求清單     | +205 行    | 3 小時   | 無（建議最後）|
| **合計** |              | **+625 行** | **約 8.25 小時** | |

> 目前 guide.html 約 951 行（2026-04-29 量測）。完成五個 Stage 後預估增加約 625 行，最終約 1576 行。

---

## 各 Stage 完成後的 Commit 建議

```
feat: add task type badges and filter tabs            ← Stage A
feat: add per-category progress bars                  ← Stage B
feat: add quest path planner with topological sort    ← Stage C
feat: add prerequisite jump badges                    ← Stage D
feat: add ship requirements panel                     ← Stage E
```

---

*本文件僅供實作規劃用，實際工作開始前請確認 guide.html 當前行數，並在每個 Stage 完成後更新驗收狀態。*
