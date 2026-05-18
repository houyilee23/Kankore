# Verifies that ALL inlined data blocks in guide.html semantically match their
# data/*.json source files. Covers six blocks:
#   const TASKS = [...]            vs data/tasks.json
#   const IMPROVEMENTS = {...}     vs data/improvements.json
#   const AREAS = {...}            vs data/areas.json
#   const EXPEDITIONS = {...}      vs data/expeditions.json
#   const BUILDS = {...}           vs data/builds.json
#   const DEVELOPMENTS = {...}     vs data/developments.json
#
# Comparison is order-insensitive on object keys.
# Exits 0 on success, 1 on any mismatch.
#
# Run with: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify_synced.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$htmlPath = Join-Path $root 'guide.html'

# ----------------------------------------------------------------------------
# Helpers: canonical normalization (sorts object keys, recurses through arrays)
# ----------------------------------------------------------------------------
function Canonicalize($v) {
    if ($null -eq $v) { return $null }
    if ($v -is [string]) { return $v }
    if ($v -is [bool] -or $v -is [int] -or $v -is [long] -or $v -is [double]) { return $v }
    if ($v -is [System.Collections.IList]) {
        return ,@($v | ForEach-Object { Canonicalize $_ })
    }
    if ($v -is [pscustomobject]) {
        $sorted = [ordered]@{}
        foreach ($n in ($v.PSObject.Properties.Name | Sort-Object)) {
            $sorted[$n] = Canonicalize $v.$n
        }
        return [pscustomobject]$sorted
    }
    return $v
}

function ToCanonString($v) {
    if ($null -eq $v) { return 'null' }
    if ($v -is [bool]) { return $v.ToString().ToLower() }
    if ($v -is [string]) { return '"' + $v.Replace('\','\\').Replace('"','\"') + '"' }
    if ($v -is [int] -or $v -is [long] -or $v -is [double]) { return $v.ToString() }
    if ($v -is [System.Collections.IList]) {
        return '[' + (($v | ForEach-Object { ToCanonString $_ }) -join ',') + ']'
    }
    if ($v -is [pscustomobject]) {
        $parts = @()
        foreach ($p in $v.PSObject.Properties) {
            $parts += '"' + $p.Name + '":' + (ToCanonString $p.Value)
        }
        return '{' + ($parts -join ',') + '}'
    }
    return $v.ToString()
}

# ----------------------------------------------------------------------------
# Extracts the inlined literal that follows `const <Name> = ` from guide.html
# and parses it as JSON. The literal can be either [...] (TASKS) or {...}.
# ----------------------------------------------------------------------------
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)

function ExtractInlineLiteral([string]$constName) {
    $pattern = '(?s)const ' + [regex]::Escape($constName) + ' = (.+?);[\r\n]'
    $m = [regex]::Match($html, $pattern)
    if (-not $m.Success) { return $null }
    return $m.Groups[1].Value | ConvertFrom-Json
}

function LoadJson([string]$relPath) {
    $p = Join-Path $root $relPath
    if (-not (Test-Path $p)) { return $null }
    return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

# ----------------------------------------------------------------------------
# Per-block validators. Each returns @{ ok = $true/false; msg = '...' }.
# Identity key for each item lets us spot missing/added rows precisely.
# ----------------------------------------------------------------------------
function Compare-ItemSets($jsonItems, $htmlItems, $keyFn) {
    if ($jsonItems.Count -ne $htmlItems.Count) {
        return @{ ok = $false; msg = "count differs - JSON $($jsonItems.Count), HTML $($htmlItems.Count)" }
    }
    $jsonMap = @{}
    foreach ($it in $jsonItems) { $jsonMap[(& $keyFn $it)] = ToCanonString (Canonicalize $it) }
    $htmlMap = @{}
    foreach ($it in $htmlItems) { $htmlMap[(& $keyFn $it)] = ToCanonString (Canonicalize $it) }
    $diffs = @()
    foreach ($k in $jsonMap.Keys) {
        if (-not $htmlMap.ContainsKey($k)) { $diffs += "missing in HTML: $k"; continue }
        if ($jsonMap[$k] -ne $htmlMap[$k]) { $diffs += "differs: $k" }
    }
    foreach ($k in $htmlMap.Keys) {
        if (-not $jsonMap.ContainsKey($k)) { $diffs += "missing in JSON: $k" }
    }
    if ($diffs.Count -eq 0) { return @{ ok = $true; msg = "$($jsonItems.Count) items match" } }
    return @{ ok = $false; msg = "$($diffs.Count) diff(s): " + (($diffs | Select-Object -First 5) -join '; ') }
}

$blocks = @(
    @{
        name = 'tasks'
        const = 'TASKS'
        json = 'data\tasks.json'
        getItems = { param($d) $d }            # tasks.json is bare array
        keyFn = { param($it) $it.id }
    },
    @{
        name = 'improvements'
        const = 'IMPROVEMENTS'
        json = 'data\improvements.json'
        getItems = { param($d) $d.items }
        keyFn = { param($it)
            $sec = if ($null -eq $it.secretary) { '' } else { (($it.secretary | ForEach-Object { $_ }) -join '|') }
            "$($it.category)::$($it.name)::$sec::$($it.updates_to)"
        }
    },
    @{
        name = 'areas'
        const = 'AREAS'
        json = 'data\areas.json'
        getItems = { param($d) $d.items }
        keyFn = { param($it) "$($it.area)::$($it.node)" }
    },
    @{
        name = 'expeditions'
        const = 'EXPEDITIONS'
        json = 'data\expeditions.json'
        getItems = { param($d) $d.items }
        keyFn = { param($it) "$($it.id)" }
    },
    @{
        name = 'builds'
        const = 'BUILDS'
        json = 'data\builds.json'
        getItems = { param($d) $d.recipes }
        keyFn = { param($it) "$($it.category)::$($it.fuel)/$($it.ammo)/$($it.steel)/$($it.bauxite)::$($it.target)" }
    },
    @{
        name = 'developments'
        const = 'DEVELOPMENTS'
        json = 'data\developments.json'
        getItems = { param($d) $d.items }
        keyFn = { param($it) "$($it.category)::$($it.fuel)/$($it.ammo)/$($it.steel)/$($it.bauxite)::$($it.output)" }
    }
)

$totalFail = 0
foreach ($b in $blocks) {
    $jsonDoc = LoadJson $b.json
    if (-not $jsonDoc) {
        Write-Host ("SKIP [$($b.name)]: $($b.json) not present")
        continue
    }
    $htmlDoc = ExtractInlineLiteral $b.const
    if (-not $htmlDoc) {
        Write-Host ("FAIL [$($b.name)]: const $($b.const) not found in guide.html")
        $totalFail++
        continue
    }
    $jsonItems = & $b.getItems $jsonDoc
    $htmlItems = & $b.getItems $htmlDoc
    $r = Compare-ItemSets $jsonItems $htmlItems $b.keyFn
    if ($r.ok) {
        Write-Host ("OK [$($b.name)]: " + $r.msg)
    } else {
        Write-Host ("FAIL [$($b.name)]: " + $r.msg)
        $totalFail++
    }
}

if ($totalFail -eq 0) { exit 0 }
exit 1
