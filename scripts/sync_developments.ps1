# Reads data/developments.json and inlines it into guide.html as `const DEVELOPMENTS = {...};`.
# Sentinel: // <DEVELOPMENTS_START> ... // <DEVELOPMENTS_END>
# Bootstrap inserts after // <BUILDS_END>.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$htmlPath = Join-Path $root 'guide.html'
$jsonPath = Join-Path $root 'data\developments.json'

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
                if ($codePoint -ge 0x80) { [void]$sb.Append([char]$codePoint); $i += 6; continue }
            }
            if ($next -eq '/') { [void]$sb.Append('/'); $i += 2; continue }
            [void]$sb.Append($c); [void]$sb.Append($next); $i += 2; continue
        }
        [void]$sb.Append($c); $i++
    }
    return $sb.ToString()
}
function CompactValue($v) {
    $compact = $v | ConvertTo-Json -Compress -Depth 10
    return Unescape-NonAsciiJson $compact
}

$data = [System.IO.File]::ReadAllText($jsonPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

$blockLines = New-Object System.Collections.Generic.List[string]
$blockLines.Add('// <DEVELOPMENTS_START> generated from data/developments.json by scripts/sync_developments.ps1; do not edit by hand')
$blockLines.Add('const DEVELOPMENTS = {')
$blockLines.Add('  "version": ' + $data.version + ',')
$blockLines.Add('  "source": ' + (CompactValue $data.source) + ',')
$blockLines.Add('  "note": ' + (CompactValue $data.note) + ',')
$blockLines.Add('  "categories": ' + (CompactValue $data.categories) + ',')
$blockLines.Add('  "items": [')
for ($i = 0; $i -lt $data.items.Count; $i++) {
    $compact = CompactValue $data.items[$i]
    $suffix = if ($i -lt $data.items.Count - 1) { ',' } else { '' }
    $blockLines.Add("    $compact$suffix")
}
$blockLines.Add('  ]')
$blockLines.Add('};')
$blockLines.Add('// <DEVELOPMENTS_END>')
$newBlock = $blockLines -join "`n"

$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$sentinel = '(?s)// <DEVELOPMENTS_START>.*?// <DEVELOPMENTS_END>'
$ev = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $newBlock }

if ([regex]::IsMatch($html, $sentinel)) {
    $rx = New-Object System.Text.RegularExpressions.Regex($sentinel, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $html = $rx.Replace($html, $ev, 1)
    $mode = 'sentinel-replace'
} else {
    $anchor = '// <BUILDS_END>'
    if (-not [regex]::IsMatch($html, $anchor)) { throw "Anchor '// <BUILDS_END>' missing; run sync_builds.ps1 first." }
    $insertText = "// <BUILDS_END>`n`n" + $newBlock
    $ev2 = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $insertText }
    $rx = New-Object System.Text.RegularExpressions.Regex($anchor)
    $html = $rx.Replace($html, $ev2, 1)
    $mode = 'bootstrap (after BUILDS_END)'
}

$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($htmlPath, $html, $enc)
Write-Host ("Synced {0} development recipes to guide.html ({1})" -f $data.items.Count, $mode)
