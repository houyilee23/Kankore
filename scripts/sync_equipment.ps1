# Reads data/equipment.json and inlines into guide.html as `const EQUIPMENT = {...};`.
# Sentinel: // <EQUIPMENT_START> ... // <EQUIPMENT_END>
# Bootstrap inserts after // <DEVELOPMENTS_END>.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$htmlPath = Join-Path $root 'guide.html'
$jsonPath = Join-Path $root 'data\equipment.json'

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

# Equipment data is a single nested object (aa.groups[].effects[], etc), small
# enough to emit as one whole compact-but-readable literal. We give it a 2-line
# wrap by laying each top-level subsection (aa/day/night) on its own line.
$blockLines = New-Object System.Collections.Generic.List[string]
$blockLines.Add('// <EQUIPMENT_START> generated from data/equipment.json by scripts/sync_equipment.ps1; do not edit by hand')
$blockLines.Add('const EQUIPMENT = {')
$blockLines.Add('  "version": ' + $data.version + ',')
$blockLines.Add('  "source": ' + (CompactValue $data.source) + ',')
$blockLines.Add('  "note": ' + (CompactValue $data.note) + ',')
$blockLines.Add('  "aa": '    + (CompactValue $data.aa)    + ',')
$blockLines.Add('  "day": '   + (CompactValue $data.day)   + ',')
$blockLines.Add('  "night": ' + (CompactValue $data.night))
$blockLines.Add('};')
$blockLines.Add('// <EQUIPMENT_END>')
$newBlock = $blockLines -join "`n"

$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$sentinel = '(?s)// <EQUIPMENT_START>.*?// <EQUIPMENT_END>'
$ev = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $newBlock }

if ([regex]::IsMatch($html, $sentinel)) {
    $rx = New-Object System.Text.RegularExpressions.Regex($sentinel, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $html = $rx.Replace($html, $ev, 1)
    $mode = 'sentinel-replace'
} else {
    $anchor = '// <DEVELOPMENTS_END>'
    if (-not [regex]::IsMatch($html, $anchor)) { throw "Anchor '// <DEVELOPMENTS_END>' missing; run sync_developments.ps1 first." }
    $insertText = "// <DEVELOPMENTS_END>`n`n" + $newBlock
    $ev2 = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $insertText }
    $rx = New-Object System.Text.RegularExpressions.Regex($anchor)
    $html = $rx.Replace($html, $ev2, 1)
    $mode = 'bootstrap (after DEVELOPMENTS_END)'
}

$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($htmlPath, $html, $enc)
Write-Host ("Synced EQUIPMENT to guide.html ({0})" -f $mode)
