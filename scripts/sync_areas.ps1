# Reads data/areas.json and inlines it into guide.html as `const AREAS = {...};`.
# Writes between sentinels // <AREAS_START> ... // <AREAS_END>.
# On first run (no sentinels), inserts after // <IMPROVEMENTS_END>.
# guide.html is written as UTF-8 without BOM.

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$htmlPath = Join-Path $root 'guide.html'
$jsonPath = Join-Path $root 'data\areas.json'

# Same unescaper as sync_tasks.ps1 / sync_improvements.ps1.
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

function CompactValue($v) {
    $compact = $v | ConvertTo-Json -Compress -Depth 10
    return Unescape-NonAsciiJson $compact
}

$dataText = [System.IO.File]::ReadAllText($jsonPath, [System.Text.Encoding]::UTF8)
$data = $dataText | ConvertFrom-Json

if (-not $data.items) {
    throw "areas.json missing 'items' array"
}

$itemFieldOrder = @('area', 'node', 'fleet_flag', 'fleet_escort', 'nav_flag', 'nav_escort', 'unlock', 'notes', 'recon', 'restricted', 'tasks')

function Reorder-Item($obj, $order) {
    $remaining = [ordered]@{}
    foreach ($p in $obj.PSObject.Properties) { $remaining[$p.Name] = $p.Value }
    $ordered = [ordered]@{}
    foreach ($f in $order) {
        if ($remaining.Contains($f)) {
            $ordered[$f] = $remaining[$f]
            $remaining.Remove($f)
        }
    }
    foreach ($k in $remaining.Keys) { $ordered[$k] = $remaining[$k] }
    return [pscustomobject]$ordered
}

$blockLines = New-Object System.Collections.Generic.List[string]
$startMark = '// <AREAS_START> generated from data/areas.json by scripts/sync_areas.ps1; do not edit by hand'
$endMark   = '// <AREAS_END>'

$blockLines.Add($startMark)
$blockLines.Add('const AREAS = {')
$blockLines.Add('  "version": ' + $data.version + ',')
$blockLines.Add('  "source": ' + (CompactValue $data.source) + ',')
$blockLines.Add('  "note": ' + (CompactValue $data.note) + ',')
$blockLines.Add('  "areas": ' + (CompactValue $data.areas) + ',')
$blockLines.Add('  "items": [')

$items = $data.items
for ($i = 0; $i -lt $items.Count; $i++) {
    $reordered = Reorder-Item $items[$i] $itemFieldOrder
    $compact = CompactValue $reordered
    $suffix = if ($i -lt $items.Count - 1) { ',' } else { '' }
    $blockLines.Add("    $compact$suffix")
}

$blockLines.Add('  ]')
$blockLines.Add('};')
$blockLines.Add($endMark)
$newBlock = $blockLines -join "`n"

$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)

$sentinelPattern = '(?s)// <AREAS_START>.*?// <AREAS_END>'
$evaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $newBlock }

if ([regex]::IsMatch($html, $sentinelPattern)) {
    $regex = New-Object System.Text.RegularExpressions.Regex($sentinelPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $newHtml = $regex.Replace($html, $evaluator, 1)
    $mode = 'sentinel-replace'
}
else {
    $impEndPattern = '// <IMPROVEMENTS_END>'
    if (-not [regex]::IsMatch($html, $impEndPattern)) {
        throw "Could not locate '// <IMPROVEMENTS_END>' anchor; run sync_improvements.ps1 first to bootstrap."
    }
    $insertText = "// <IMPROVEMENTS_END>`n`n" + $newBlock
    $insertEvaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $insertText }
    $regex = New-Object System.Text.RegularExpressions.Regex($impEndPattern)
    $newHtml = $regex.Replace($html, $insertEvaluator, 1)
    $mode = 'bootstrap (inserted after IMPROVEMENTS_END)'
}

$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($htmlPath, $newHtml, $encoding)

Write-Host "Synced $($items.Count) area entries to guide.html ($mode)"
