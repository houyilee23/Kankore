# Reads data/tasks.json and inlines it into guide.html as `const TASKS = [...]`.
# Writes between sentinels // <TASKS_START> ... // <TASKS_END>.
# On first run (no sentinels yet), finds `const TASKS = [...]` and wraps it in sentinels.
# guide.html is written as UTF-8 without BOM.
#
# Run with: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/sync_tasks.ps1

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$htmlPath = Join-Path $root 'guide.html'
$jsonPath = Join-Path $root 'data\tasks.json'

# Same canonical field order as extract_tasks.ps1.
$fieldOrder = @(
    'id', 'name', 'cat', 'kind', 'type',
    'recurrence', 'tags',
    'prev', 'next',
    'require_ships', 'require_strict_forms',
    'rewards',
    'info', 'content', 'unlock', 'reward_text'
)

function Unescape-NonAsciiJson([string]$s) {
    $sb = [System.Text.StringBuilder]::new($s.Length)
    $i = 0
    while ($i -lt $s.Length) {
        $c = $s[$i]
        if ($c -eq '\' -and $i + 1 -lt $s.Length) {
            $next = $s[$i+1]
            if ($next -eq 'u' -and $i + 5 -lt $s.Length) {
                $hex = $s.Substring($i+2, 4)
                $codePoint = [Convert]::ToInt32($hex, 16)
                if ($codePoint -ge 0x80) {
                    [void]$sb.Append([char]$codePoint)
                    $i += 6
                    continue
                }
            }
            if ($next -eq '/') {
                [void]$sb.Append('/')
                $i += 2
                continue
            }
            [void]$sb.Append($c)
            [void]$sb.Append($next)
            $i += 2
            continue
        }
        [void]$sb.Append($c)
        $i++
    }
    return $sb.ToString()
}

function Reorder-Object($obj, $order) {
    $remaining = [ordered]@{}
    foreach ($p in $obj.PSObject.Properties) { $remaining[$p.Name] = $p.Value }

    $ordered = [ordered]@{}
    foreach ($f in $order) {
        if ($remaining.Contains($f)) {
            $ordered[$f] = $remaining[$f]
            $remaining.Remove($f)
        }
    }
    foreach ($k in $remaining.Keys) {
        $ordered[$k] = $remaining[$k]
    }
    return [pscustomobject]$ordered
}

# Read tasks.json.
$tasksRaw = [System.IO.File]::ReadAllText($jsonPath, [System.Text.Encoding]::UTF8)
$tasks = $tasksRaw | ConvertFrom-Json
$tasks = $tasks | Sort-Object -Property id
$reordered = $tasks | ForEach-Object { Reorder-Object $_ $fieldOrder }

# Build the multi-line TASKS literal embedded in HTML.
$inner = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $reordered.Count; $i++) {
    $compact = $reordered[$i] | ConvertTo-Json -Compress -Depth 10
    $compact = Unescape-NonAsciiJson $compact
    $suffix = if ($i -lt $reordered.Count - 1) { ',' } else { '' }
    $inner.Add("  $compact$suffix")
}

$startMark = '// <TASKS_START> generated from data/tasks.json by scripts/sync_tasks.ps1; do not edit by hand'
$endMark   = '// <TASKS_END>'

$blockLines = New-Object System.Collections.Generic.List[string]
$blockLines.Add($startMark)
$blockLines.Add('const TASKS = [')
foreach ($l in $inner) { $blockLines.Add($l) }
$blockLines.Add('];')
$blockLines.Add($endMark)
$newBlock = $blockLines -join "`n"

# Read HTML.
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)

$sentinelPattern = '(?s)// <TASKS_START>.*?// <TASKS_END>'
$bareTasksPattern = '(?s)const TASKS = \[.*?\];'

# Use a MatchEvaluator delegate for the replacement so dollar-signs and backslashes
# in $newBlock are not interpreted as regex backreferences.
$evaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $newBlock }

if ([regex]::IsMatch($html, $sentinelPattern)) {
    $regex = New-Object System.Text.RegularExpressions.Regex($sentinelPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $newHtml = $regex.Replace($html, $evaluator, 1)
    $mode = 'sentinel-replace'
}
elseif ([regex]::IsMatch($html, $bareTasksPattern)) {
    $regex = New-Object System.Text.RegularExpressions.Regex($bareTasksPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $newHtml = $regex.Replace($html, $evaluator, 1)
    $mode = 'bootstrap (added sentinels)'
}
else {
    throw "Could not locate TASKS block (no sentinels and no 'const TASKS = [...]' literal) in $htmlPath"
}

# Write HTML back as UTF-8 without BOM.
$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($htmlPath, $newHtml, $encoding)

Write-Host "Synced $($reordered.Count) tasks to guide.html ($mode)"
