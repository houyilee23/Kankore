# 艦これ改 任務追蹤器 — 專案說明（CLAUDE.md）

> 本文件供 Claude Code session 自動讀取，記錄專案的架構約束、資料模型、工作慣例。  
> 每次開新 session 前請先確認本文件是否有更新。

---

## 專案性質

- **名稱**：艦これ改（艦隊これくしょん改）任務追蹤器
- **用途**：作者個人手機使用，用於追蹤遊戲任務 DAG 的完成進度
- **部署**：GitHub Pages（repo: `houyilee23/Kankore`），主檔為 `guide.html`
- **目前規模**：約 131 個任務節點，含 9 大分類（編成/出撃/演習/遠征/補給入渠/工廠/改装/改修/ケッコンカッコカリ）+ 多維標籤系統
- **設計目標**：手機優先、單一 HTML 離線可用、輕量快速

---

## 架構約束（硬規則）

下列規則**不得違反**，即使使用者沒有明確提醒也必須遵守：

### 單一 HTML 檔案
- 主檔固定為 `guide.html`，**CSS 與 JS 全部 inline**（分別放在 `<style>` 與 `<script>` tag 內）
- **不准**拆分成多個 .js / .css / .html 檔案
- **不准**引入任何 framework（React / Vue / Angular / Svelte / Preact 等，全部禁止）
- **不准**引入任何 build tool / bundler（webpack / vite / rollup / parcel 等，全部禁止）
- **不准**引入外部 CDN script（`<script src="https://...">`）；所有第三方邏輯若真有必要，必須完整 inline

### 離線可用
- **不准**依賴外部 API（no fetch 到外部 URL）
- **不准**依賴外部字型（no Google Fonts CDN）
- **不准**依賴外部圖片（no `<img src="https://...">`）
- Service Worker / PWA 快取可使用，但不是強制

### 禁止依賴現實時間的功能
- 遊戲的月刊/週刊/年刊 reset **不對應現實時間**（由遊戲內部觸發，與現實月份/週數無關）
- **不准**實作倒數計時器（distance to reset）
- **不准**實作「今日推薦任務」等依賴現實日期的邏輯
- 若使用者特別要求時間相關功能，需先確認遊戲機制再實作

---

## 手機優先約束

- **主要目標瀏覽器**：iOS Safari 16+、Android Chrome 108+
- **PWA meta tags 必須維持**：
  ```html
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="theme-color" content="#1a1d23">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  ```
- `env(safe-area-inset-*)` padding 必須維持（iPhone 劉海/底部 Home Bar）
- **觸控目標最小 44×44 px**（checkbox、button、toggle 等）
- **不准**使用 hover-only 互動（手機沒有 hover 狀態）；互動狀態一律用 tap/active
- 深色主題為主（背景 `#1a1d23`，不提供淺色切換選項）
- 字型大小：body 16px，meta 資訊最小 11px

---

## 資料模型

### TASKS 陣列

`guide.html` 內有一個全域 `const TASKS = [...]`，每筆為一個任務物件。

#### 現有欄位

| 欄位           | 類型                          | 說明                                         |
|---------------|-------------------------------|----------------------------------------------|
| `id`          | `string`                      | 任務編號，格式 `t001`～`t141`                 |
| `name`        | `string`                      | 任務名稱（日文）                              |
| `cat`         | `string`                      | **主分類**（9 種固定值，見下方）                |
| `kind`        | `'task'｜'note'｜'reward'`    | 節點類型；只有 `task` 會算進完成度            |
| `prev`        | `string[]`                    | 前置任務 id 陣列（DAG 邊）                    |
| `next`        | `string[]`                    | 後續任務 id 陣列（DAG 邊）                    |
| `info`        | `string[]`                    | 編成/海域/補充說明（非結構化文字陣列）         |
| `content`     | `string`（可選）               | 達成條件說明                                 |
| `unlock`      | `string`（可選）               | 開放條件文字                                 |
| `reward_text` | `string`（可選）               | 報酬文字（如「開発資材x3 勲章x1」）           |
| `rewards`     | `string[]`（可選）             | 特定裝備/艦娘名稱陣列                         |
| `recurrence`  | `'daily'｜'weekly'｜'monthly'｜'yearly'`（可選） | 週期性標記（同時也應加入對應 tag） |
| `type`        | `'sortie'｜'exercise'｜'expedition'｜'factory'｜'remodel'｜'formation'｜'supply'｜'improve'｜'marriage'`（可選） | 任務種類 (與 cat 一一對應，但語意上是「徽章顏色」標識) |
| `tags`        | `string[]`（可選）             | **附加標籤**（多維、可複數、可搜尋；見下方標籤清單） |
| `require_ships` | `string[]`（可選）          | 所需艦娘名稱清單（結構化）；以 base 級別判定持有，任一改型即視為滿足 |
| `require_strict_forms` | `string[]`（可選）   | 嚴格指定特定艦娘型態（罕見例外，如 t079 必須未改造的「大鯨」，龍鳳/龍鳳改不可）；檢查 `shipsState.ownedForms[form]`，base 級別持有不視為滿足 |

#### 9 大主分類（`cat` 合法值）

由 `const CATEGORIES` 鎖定。任何新增任務的 `cat` 必須為下列其中之一：

| `cat`                | 對應 `type`     | 說明                |
|----------------------|----------------|---------------------|
| `編成`               | `formation`    | 艦隊編成相關         |
| `出撃`               | `sortie`       | 出撃海域作戰         |
| `演習`               | `exercise`     | 演習對戰             |
| `遠征`               | `expedition`   | 遠征派遣             |
| `補給/入渠`           | `supply`       | 補給/入渠維護        |
| `工廠`               | `factory`      | 建造/解體/廢棄       |
| `改装`               | `remodel`      | 艦娘改装/改二        |
| `改修`               | `improve`      | 改修工廠裝備強化     |
| `ケッコンカッコカリ`   | `marriage`     | ケッコン儀式         |

#### 標籤系統（`tags`）

附加維度，多個任務可共用、單一任務可掛多個。由 `const KNOWN_TAGS` 列舉預設值，使用者搜尋與 tab 篩選都會吃這欄。

| 標籤            | 用途                                                |
|-----------------|----------------------------------------------------|
| `daily`         | 日刊（與 `recurrence='daily'` 同步）                 |
| `weekly`        | 週刊（與 `recurrence='weekly'` 同步）                |
| `monthly`       | 月刊（與 `recurrence='monthly'` 同步）               |
| `yearly`        | 年刊（與 `recurrence='yearly'` 同步）                |
| `艦隊解放`       | 解放新艦隊欄位的關鍵任務                              |
| `明石入手`       | 明石獲取鏈條                                         |
| `海外艦`         | 取得任意海外艦（Littorio 或 Z1）的任務                |
| `Littorio`      | Littorio 線專屬                                     |
| `Z1`            | Z1 線專屬                                           |
| `鹿島`          | 鹿島入手鏈                                          |
| `卯月`          | 卯月入手鏈                                          |
| `周回`          | 需多次重複出撃 / 反復成功                            |
| `レア装備`       | 報酬含使用者「體感稀有」清單之裝備（56 項，見 commit 紀錄） |
| `reward`        | `kind='reward'` 節點自動帶（無需手動加）              |

新增標籤前先 review 現有命名以避免分散；若加入未在 `KNOWN_TAGS` 的標籤，UI 會自動顯示在 tab 列尾端。

#### id 命名規則

- 格式固定為 `t` + 零填充三位數（`t001`～`t999`）
- **不可重排現有 id**，因為 `prev`/`next` 欄位有交叉引用
- 新增任務從 `t142` 開始編號（t130～t141 已用於 daily/weekly/monthly 通用任務 + 各 cat 種子）

---

## localStorage Key 規範

### 現有 key

| Key                   | 說明                                                                       |
|----------------------|----------------------------------------------------------------------------|
| `kc_quest_state_v2`  | 主要狀態物件，包含子欄位：`done`、`notes`、`prevAdd`、`prevRemove`、`recentLimit`、`pinnedGoals` |
| `kc_ships_v1`        | 艦娘持有狀態：`owned`（base 級）、`pinned`（base 級）、`foldedTypes`、`ownedForms`（特定型態級，搭配 `require_strict_forms`） |

### 命名規則

- 格式：`kc_<feature>_v<N>`
- 版本號（`v<N>`）在資料結構變更時必須 bump，舊版 key 不可直接覆寫（需遷移或清除舊值）

### 規劃中新增 key

| Key             | 說明               |
|----------------|--------------------|
| `kc_prefs_v1`  | 使用者偏好設定       |

---

## 遊戲機制備註

- **DAG 任務依賴**：任務之間的解鎖關係是有向無環圖（DAG），以 `prev`/`next` 表示
- **隱藏前置任務**：部分 wiki 上沒有明確記載的隱藏前置，使用者可透過 `prevAdd`/`prevRemove` 自行修正 DAG 邊
- **recurrence 機制**：月刊/年刊任務完成後不會自動 reset，使用者需手動重置（或透過「一鍵 Reset」功能）；reset 時機由遊戲內部決定，**不對應現實時間**
- **kind 區分**：`reward` 類節點僅代表「獲得特定獎勵」的里程碑，不是可勾選的任務；`note` 類節點是說明性節點，兩者均不計入完成度

---

## Coding 風格

- **JS 版本**：ES2020+（箭頭函數、template literals、optional chaining `?.`、nullish coalescing `??` 均可用）
- **不要 minify**：維持可讀性，縮排用 2 個空格
- **命名**：
  - 函數、變數 → `camelCase`
  - 全域常數 → `UPPER_SNAKE_CASE`（如 `TASKS`、`STORAGE_KEY`）
  - CSS class → `kebab-case`
- **CSS 變數**：所有色票、間距等設計 token 統一定義在 `:root`，不得在 rule 內直接寫死顏色值
- **現有 CSS 色票參考**：
  ```css
  :root {
    --bg: #1a1d23;        /* 主背景 */
    --panel: #252932;     /* 卡片背景 */
    --panel-2: #2e3340;   /* 展開區塊背景 */
    --border: #3a3f4d;    /* 邊框 */
    --text: #e6e8eb;      /* 主文字 */
    --text-dim: #9aa0ab;  /* 次要文字 */
    --accent: #5ea0ef;    /* 強調藍 */
    --done: #3a7d44;      /* 完成綠 */
    --done-dim: #2a5a32;
    --avail: #5ea0ef;     /* 可進行藍 */
    --upcoming: #c89b3c;  /* 待解鎖橘 */
    --note: #c89b3c;
    --type-sortie: #e05555;      /* 任務類型：出撃 */
    --type-exercise: #5ea0ef;    /* 任務類型：演習 */
    --type-expedition: #4caf7d;  /* 任務類型：遠征 */
    --type-factory: #9c7cd4;     /* 任務類型：工廠 */
    --type-remodel: #e07b30;     /* 任務類型：改裝 */
    --type-formation: #9aa0ab;   /* 任務類型：編成 */
  }
  ```
- **Hard-coded 顏色**（標籤系統與 focus 區塊頭使用）：
  - `#d76e8a` 月刊/釘選粉
  - `#c89b3c` 年刊/upcoming 黃
  - `#5ea0ef` 週刊/avail 藍
  - `#4caf7d` 日刊/done 綠
  - `#b89df0` レア装備/recurring 紫
  - `#e07b30` blocked/改裝橘
- **注意**：新增 CSS 變數時要加在 `:root` 區塊，並在本文件的色票參考中補充記錄

---

## 工作流程

1. 每次改動完成後，先**回報變更摘要**給使用者 review
2. 使用者確認後才執行 `git add` + `git commit` + `git push`
3. **Commit message 格式**（英文）：
   - `feat: <簡短說明>` — 新功能
   - `fix: <簡短說明>` — Bug 修正
   - `refactor: <簡短說明>` — 重構（不改行為）
   - `docs: <簡短說明>` — 文件更新
   - `style: <簡短說明>` — 純 CSS/視覺調整
   - 範例：`feat: add task type badges and filter tabs`
4. Push 前確認 `git status` 顯示 working tree 乾淨
5. **不可直接 force push**，如有衝突先回報給使用者

---

## 工具環境注意事項

### PowerShell 是唯一可用的腳本工具

本機（Windows）**沒有**安裝 Node.js / Python / jq，所有資料轉換腳本必須用 PowerShell。
範例：批次修改 `TASKS` JSON、跑遷移、產生診斷報告等。

### PowerShell 腳本必須是 UTF-8 BOM

PowerShell 5.1 預設用系統 codepage（cp950 / Big5）讀取無 BOM 的 .ps1，
含日文/中文字元的腳本若沒有 BOM 會出現 parser error（`非預期的權杖`）。

**腳本撰寫流程**：
1. 用 `Write` 工具建立 `.ps1` 內容（這會產生**無 BOM** 的 UTF-8）
2. 用一支 ASCII-only 的 helper（`add_bom.ps1`）把它轉成 UTF-8 BOM：
   ```powershell
   param([string]$Path)
   $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
   $utf8bom = New-Object System.Text.UTF8Encoding($true)
   [System.IO.File]::WriteAllText($Path, $content, $utf8bom)
   ```
3. 跑 `add_bom.ps1` → 再跑目標腳本
4. 一次性腳本跑完後 **必須清理**（`rm migrate.ps1 add_bom.ps1`），不留進 commit

### PowerShell 寫檔注意事項

- 讀檔用 `[System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)`，**不要**用裸 `Get-Content`（會吃系統 codepage）
- 寫檔用 `[System.IO.File]::WriteAllLines($Path, $lines, (New-Object System.Text.UTF8Encoding($false)))` 產生**無 BOM** UTF-8（`guide.html` 必須保持無 BOM）
- 終端機 stdout 出現亂碼是 cp950 console 顯示的問題，**不影響檔案實際內容**；要驗證資料就把報告寫進 .txt 再用 `Read` 工具讀

### 免確認執行的選項

執行 PowerShell 腳本時加 `-NoProfile -ExecutionPolicy Bypass -File <script>`，可避免互動式確認與 profile 干擾：
```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File migrate.ps1
```
若使用者開啟 Auto Mode，所有 `Bash` 工具呼叫不會跳出確認，可直接連續執行。

---

## 參考文件

| 檔案                              | 說明                                           |
|----------------------------------|------------------------------------------------|
| `notes/feature-ideas.md`         | 完整功能規劃比較研究（差距分析、候選功能清單）    |
| `notes/implementation-plan.md`   | 目前這一輪的分階段實作計畫（Stage A～E）          |
