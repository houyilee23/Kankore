# Extracts TASKS array from guide.html into data/tasks.json.
# One task per line, canonical field order, sorted by id, non-ASCII inlined as UTF-8.
# ASCII-only source (no BOM needed).

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$htmlPath = Join-Path $root 'guide.html'
$jsonPath = Join-Path $root 'data\tasks.json'

# Canonical field order. Any unknown fields are appended after these in their input order.
$fieldOrder = @(
    'id', 'name', 'cat', 'kind', 'type',
    'recurrence', 'tags',
    'prev', 'next',
    'require_ships', 'require_strict_forms',
    'rewards',
    'info', 'content', 'unlock', 'reward_text'
)

# PowerShell 5.1 ConvertTo-Json escapes non-ASCII as \uXXXX. Inline them back as UTF-8
# so the JSON file stays human-readable and diff-friendly. Keeps ASCII escapes intact.
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

# Read HTML and locate TASKS literal.
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$pattern = '(?s)const TASKS = (\[.*?\]);'
$m = [regex]::Match($html, $pattern)
if (-not $m.Success) {
    throw "Could not find 'const TASKS = [...]' in guide.html"
}

$tasks = $m.Groups[1].Value | ConvertFrom-Json
$tasks = $tasks | Sort-Object -Property id
$reordered = $tasks | ForEach-Object { Reorder-Object $_ $fieldOrder }

# Emit one task per line, wrapped in [ ... ].
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('[')
for ($i = 0; $i -lt $reordered.Count; $i++) {
    $compact = $reordered[$i] | ConvertTo-Json -Compress -Depth 10
    $compact = Unescape-NonAsciiJson $compact
    $suffix = if ($i -lt $reordered.Count - 1) { ',' } else { '' }
    $lines.Add("  $compact$suffix")
}
$lines.Add(']')
$lines.Add('')  # trailing newline at end of file

$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($jsonPath, ($lines -join "`n"), $encoding)

Write-Host "Extracted $($reordered.Count) tasks to $jsonPath"
