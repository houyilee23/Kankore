# Code Map — `guide.html`

> Lookup table for low-token maintenance. Find the right section by name without re-reading the entire file.

The whole app is ONE HTML file (~5000 lines) because the architecture mandates a single self-contained file. To keep edits cheap, this map points at every meaningful section by **what it does** and where to find it (line ranges + grep anchors). When line numbers drift, re-grep for the anchor.

---

## Top-down structure

| Section | Lines (approx) | Grep anchor |
|---|---|---|
| **CSS** — design tokens (`:root`) | 11–30 | `^:root {` |
| **CSS** — global / header / view-switch / sub-tabs | 31–230 | `.view-switch` |
| **CSS** — task list & buckets (focus / all views) | ~230–610 | `.task {` / `.task-row` |
| **CSS** — planner | ~615–760 | `.planner-chip` / `.planner-step` |
| **CSS** — ships panel | ~785–1080 | `.ship-form-chip` / `.ship-warning` |
| **CSS** — `/* === 改修工廠 (Improvements) === */` | from `/* === 改修工廠` | `=== 改修工廠` |
| **CSS** — `/* === 海域 (Areas) === */` | from `/* === 海域` | `=== 海域` |
| **CSS** — `/* === 遠征 (Expeditions) === */` | from `/* === 遠征` | `=== 遠征` |
| **CSS** — `/* === 建造 / 開發 views === */` | from `/* === 建造` | `=== 建造` |
| **CSS** — bottom-bar / dialog | ~420–500 | `.bottom-bar` / `dialog` |
| **HTML** — `<header>` (h1 + progress + view-switch + sub-tabs + filters) | from `<header>` | `<header>` |
| **HTML** — main `#list` (focus/all view container) | `<main id="list">` | `<main id="list">` |
| **HTML** — `<section id="planner">` | one line | `id="planner"` |
| **HTML** — `<section id="ships-panel">` | | `id="ships-panel"` |
| **HTML** — `<section id="improvements-panel">` | | `id="improvements-panel"` |
| **HTML** — `<section id="areas-panel">` | | `id="areas-panel"` |
| **HTML** — `<section id="expeditions-panel">` | | `id="expeditions-panel"` |
| **HTML** — `<section id="builds-panel">` (new) | | `id="builds-panel"` |
| **HTML** — `<section id="developments-panel">` (new) | | `id="developments-panel"` |
| **HTML** — bottom-bar (`⚙` tray + 3 hidden buttons) | | `class="bottom-bar"` |
| **HTML** — modal `<dialog id="dlg">` for export/import | | `id="dlg"` |
| **JS** — data constants from sync scripts | `const TASKS = [` etc. | `^const TASKS =` |
| **JS** — `STORAGE_KEY`, state, save() | `const STORAGE_KEY` | `STORAGE_KEY = 'kc_quest_state_v2'` |
| **JS** — SHARED HELPERS (`htmlEscape`, `resCell`) | right after `save()` | `function htmlEscape` |
| **JS** — DAG helpers (`effPrereqs`, `isAvailable`, `computeBuckets`) | | `function effPrereqs` |
| **JS** — `const ui = { … }` (DOM cache) | | `^const ui = {` |
| **JS** — task list rendering (`render`, `renderFocus`, `renderAll`, `renderTask`, …) | | `^function render(` |
| **JS** — DAG ancestor + planner (`buildAncestors`, `topoSort`, `renderPlanner`, …) | | `^function buildAncestors` |
| **JS** — `// === Stage E: Ship roster ===` (ships data + view + `shipsState`) | | `=== Stage E:` |
| **JS** — `const SHIPS_STORAGE_KEY = 'kc_ships_v1'` | | `SHIPS_STORAGE_KEY` |
| **JS** — `const AREAS_STORAGE_KEY = 'kc_areas_v1'` | | `AREAS_STORAGE_KEY` |
| **JS** — tab switcher (`VIEW_GROUP`, `setView`, `switchTo`, click wiring) | | `^const VIEW_GROUP` |
| **JS** — export/import (`buildExportBlob`, `buildImportPatch`, `openIO`, btn-tray) | | `function buildExportBlob` |
| **JS** — `// === 改修工廠 (Improvements view) ===` | | `renderImprovements()` |
| **JS** — `// === 海域 (Areas view) ===` | | `renderAreas()` |
| **JS** — `// === 遠征 (Expeditions view) ===` | | `renderExpeditions()` |
| **JS** — `// === 建造 (Builds view) ===` | | `renderBuilds()` |
| **JS** — `// === 開発 (Developments view) ===` | | `renderDevelopments()` |
| **JS** — init block (calls `setView()`, `render()`) | last few lines before `</script>` | `^renderTabs();` |

---

## Data flow & sync pipeline

Six data sets, all source-of-truth in `data/*.json`, inlined into `guide.html` via PowerShell sync scripts:

| JSON file | Inline const | Sentinel block | Sync script |
|---|---|---|---|
| `data/tasks.json` | `const TASKS = [...]` | `// <TASKS_START>` / `<TASKS_END>` | `scripts/sync_tasks.ps1` |
| `data/improvements.json` | `const IMPROVEMENTS = {...}` | `IMPROVEMENTS_START/END` | `scripts/sync_improvements.ps1` |
| `data/areas.json` | `const AREAS = {...}` | `AREAS_START/END` | `scripts/sync_areas.ps1` |
| `data/expeditions.json` | `const EXPEDITIONS = {...}` | `EXPEDITIONS_START/END` | `scripts/sync_expeditions.ps1` |
| `data/builds.json` | `const BUILDS = {...}` | `BUILDS_START/END` | `scripts/sync_builds.ps1` |
| `data/developments.json` | `const DEVELOPMENTS = {...}` | `DEVELOPMENTS_START/END` | `scripts/sync_developments.ps1` |

**`scripts/verify_synced.ps1`** validates all 6 data blocks at once (HTML inlined data ≡ JSON source).

**Edit workflow**: change `data/*.json` → run the matching `sync_*.ps1` → run `verify_synced.ps1` → commit BOTH the JSON and `guide.html`.

---

## State / localStorage keys

| Key | What it holds | JS variable | Save fn |
|---|---|---|---|
| `kc_quest_state_v2` | `done`, `notes`, `prevAdd`, `prevRemove`, `pinnedGoals`, `recentLimit` | `state` | `save()` |
| `kc_ships_v1` | `owned`, `pinned`, `foldedTypes`, `ownedForms`, `pinnedForms` | `shipsState` | `saveShips()` |
| `kc_areas_v1` | `cleared` (map of `"<area>::<node>"` → timestamp) | `areasState` | `saveAreas()` |

**Backup format (export/import)**: `buildExportBlob()` produces a v2 envelope `{version:2, exportedAt, quest_state, ships_state, areas_state}`. `buildImportPatch()` accepts both v2 envelopes and legacy v1 (just the quest state, recognised by top-level `done` key).

---

## Common views — pattern reference

Every "non-task" view (改修, 海域, 遠征, 建造, 開発) uses the same collapsible-group pattern. Don't reinvent — copy from a working one.

### Collapsible group structure (HTML)

```html
<div class="area-group expanded">
  <div class="area-group-head" data-toggle="<group-key>">
    <span>Title <span class="dim">(N items)</span></span>
    <span class="area-toggle">▼</span>
  </div>
  <div class="area-group-body">
    <!-- cards go here -->
  </div>
</div>
```

### Collapsible group state + handler (JS, in each view's render function)

```js
const XXX_EXPANDED = new Set();  // keys currently expanded

function renderXXX() {
  // … filter / group …
  const autoExpand = !!searchQuery || activeSomeFilter;  // optional
  for (const [key, items] of groups.entries()) {
    const isExpanded = autoExpand || XXX_EXPANDED.has(key);
    const cls = 'area-group' + (isExpanded ? ' expanded' : '');
    html.push(`<div class="${cls}">`);
    html.push(`<div class="area-group-head" data-toggle="${htmlEscape(key)}">…</div>`);
    html.push(`<div class="area-group-body">…</div>`);
    html.push(`</div>`);
  }
  ui.xxxList.innerHTML = html.join('');
}

// Toggle handler (event delegation on the list container)
ui.xxxList.addEventListener('click', e => {
  const head = e.target.closest('.area-group-head');
  if (!head) return;
  const key = head.dataset.toggle;
  if (XXX_EXPANDED.has(key)) XXX_EXPANDED.delete(key);
  else XXX_EXPANDED.add(key);
  head.closest('.area-group').classList.toggle('expanded');
});
```

### Resource cell + escape helpers

Use the shared module-level helpers (defined right after `function save()` at the top of the script):
- `htmlEscape(s)` — safe innerHTML insertion
- `resCell(label, value, cls)` — colored resource pill for 燃/弾/鋼/ボ/戦P

**Do not redefine these locally** — they are intentionally shared.

---

## Tab system

5 top-level tabs:

```
📋 任務 ─ 進度焦點 (focus)  /  🗺 規劃 (planner)  /  全部清單 (all)
⚓ 艦娘 ─ (ships)
🔧 工廠 ─ ⚙ 建造 (builds)  /  🧪 開發 (developments)  /  🛠 改修 (improvements)
🧭 海域 ─ (areas)
🚢 遠征 ─ (expeditions)
```

JS:
- `VIEW_GROUP` — `viewMode → 'tasks'|'ships'|'factory'|'areas'|'expeditions'`
- `lastInGroup` — remembers the last sub-view per parent (clicking 任務/工廠 restores it)
- `setView()` — toggles `.active` classes on parent tabs + sub-tabs, shows/hides sub-tab strips, shows/hides panels, mutually exclusive
- `switchTo(vm)` — sets `viewMode`, calls `setView()`, dispatches to the appropriate renderer

**Adding a new sub-view** under 任務 or 工廠:
1. Add button to the sub-tab strip in HTML
2. Add `ui.vwNewThing` ref
3. Add entry to `VIEW_GROUP` map
4. Wire `ui.vwNewThing.onclick = () => switchTo('newthing')`
5. Add case in `switchTo()` switch
6. Add panel show/hide line in `setView()`

---

## "I want to do X" cookbook

### Add a new task field

1. Edit `data/tasks.json` for the task you want (add the field)
2. Run `scripts/sync_tasks.ps1` to inline
3. If you want it rendered, edit `renderTask()` (anchor: `^function renderTask`)
4. Document the new field in CLAUDE.md `### TASKS 陣列` table

### Add a new sea area unlock condition

1. Edit `data/areas.json` — set `unlock` on the relevant item
2. Run `scripts/sync_areas.ps1`
3. The 海域 view auto-renders unlock chips via `renderAreas()` — no code change

### Add a new top-level view (e.g. 補給)

1. Add `<button id="vw-supply">🛟 補給</button>` to `.view-switch` in HTML
2. Add `<section id="supply-panel" style="display:none">…</section>`
3. Add CSS rule (start from copying `#expeditions-panel` block)
4. Add `ui.vwSupply` and `ui.supplyPanel` refs
5. Map `VIEW_GROUP.supply = 'supply'`
6. Wire click handler, add to `setView()` panel visibility
7. Write `renderSupply()` (start from copying `renderAreas()`)
8. Call `renderSupply()` from `switchTo()`'s switch

### Add a new sub-tab under 工廠

1. Add button to `#factory-subtabs`
2. Add ui ref
3. Add case in `switchTo()` + `VIEW_GROUP`
4. `setView()` already handles the sub-tab .active toggle if you add the line for it

### Fix a bug in a single view

1. Grep for the view's render function: `grep -n '^function renderXXX' guide.html`
2. Read just that function (start–end)
3. Most bugs are in: HTML escaping, search filter logic, state management

### Bulk-edit data via PowerShell

- Read JSON with `[System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json`
- ALWAYS use UTF-8 no BOM when writing back (see existing sync scripts for pattern)
- Keep PowerShell scripts ASCII-only (Japanese chars get mangled by cp950)

---

## Verification & DAG safety

After ANY change to `data/tasks.json`:
1. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/sync_tasks.ps1`
2. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify_synced.ps1`
3. (Optional but recommended) `git diff data/tasks.json guide.html` — both files MUST be staged together

After changing prev/next: also check bidirectional consistency (the audit script proves DAG edges are mirrored).

---

## Known patterns for fewer-token edits

- **Anchors over line numbers**: line numbers drift, anchors (function names, sentinel comments, CSS selectors) survive.
- **Edit by sentinel block**: regenerating `const TASKS = [...]` from JSON is one `Bash` call. Avoid editing it directly.
- **One view per render function**: each view's renderer is self-contained. You can read one and ignore the rest.
- **Shared helpers at the top**: `htmlEscape`, `resCell`, DAG helpers are defined once. Use them, don't duplicate.
- **State keys are versioned**: `kc_*_v<N>`. If you change the shape, bump the version and migrate. Never silently overwrite.
