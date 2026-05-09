# Verifies that inlined data in guide.html semantically matches the JSON source files.
# Checks both:
#   - const TASKS = [...]        vs data/tasks.json
#   - const IMPROVEMENTS = {...} vs data/improvements.json
#
# Comparison is order-insensitive on object keys, identity by id (tasks) or by
# (category, name, secretary, updates_to) tuple (improvements, since same equipment
# can have multiple rows with different secretary requirements).
# Exits 0 on success, 1 on any mismatch.
#
# Run with: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify_synced.ps1

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$htmlPath = Join-Path $root 'guide.html'
$tasksJsonPath = Join-Path $root 'data\tasks.json'
$improvementsJsonPath = Join-Path $root 'data\improvements.json'

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

# ---------------- TASKS check ----------------

$tasksJson = [System.IO.File]::ReadAllText($tasksJsonPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)

$tasksLiteralMatch = [regex]::Match($html, '(?s)const TASKS = (\[.*?\]);')
if (-not $tasksLiteralMatch.Success) {
    Write-Host "ERROR: could not find 'const TASKS = [...]' in guide.html"
    exit 1
}
$htmlTasks = $tasksLiteralMatch.Groups[1].Value | ConvertFrom-Json

if ($tasksJson.Count -ne $htmlTasks.Count) {
    Write-Host ("FAIL [tasks]: count differs - JSON {0}, HTML {1}" -f $tasksJson.Count, $htmlTasks.Count)
    exit 1
}

$tasksMismatches = @()
$jsonTaskLookup = @{}
foreach ($t in $tasksJson) { $jsonTaskLookup[$t.id] = ToCanonString (Canonicalize $t) }
$htmlTaskLookup = @{}
foreach ($t in $htmlTasks) { $htmlTaskLookup[$t.id] = ToCanonString (Canonicalize $t) }

foreach ($id in $jsonTaskLookup.Keys) {
    if (-not $htmlTaskLookup.ContainsKey($id)) {
        $tasksMismatches += "missing in HTML: $id"
        continue
    }
    if ($jsonTaskLookup[$id] -ne $htmlTaskLookup[$id]) {
        $tasksMismatches += "differs: $id"
        $tasksMismatches += "  JSON: $($jsonTaskLookup[$id])"
        $tasksMismatches += "  HTML: $($htmlTaskLookup[$id])"
    }
}
foreach ($id in $htmlTaskLookup.Keys) {
    if (-not $jsonTaskLookup.ContainsKey($id)) {
        $tasksMismatches += "missing in JSON: $id"
    }
}

# ---------------- IMPROVEMENTS check ----------------

$improvementsMismatches = @()
$improvementsCount = 0

if (Test-Path $improvementsJsonPath) {
    $improvementsJson = [System.IO.File]::ReadAllText($improvementsJsonPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

    $impLiteralMatch = [regex]::Match($html, '(?s)const IMPROVEMENTS = (\{.*?\});')
    if (-not $impLiteralMatch.Success) {
        $improvementsMismatches += "missing 'const IMPROVEMENTS = {...}' in guide.html"
    }
    else {
        $htmlImprovements = $impLiteralMatch.Groups[1].Value | ConvertFrom-Json

        if ($improvementsJson.items.Count -ne $htmlImprovements.items.Count) {
            $improvementsMismatches += ("count differs - JSON {0}, HTML {1}" -f $improvementsJson.items.Count, $htmlImprovements.items.Count)
        }
        $improvementsCount = $improvementsJson.items.Count

        function ItemKey($it) {
            $sec = if ($null -eq $it.secretary) { '' } else { (($it.secretary | ForEach-Object { $_ }) -join '|') }
            return "$($it.category)::$($it.name)::$sec::$($it.updates_to)"
        }

        $jsonImpLookup = @{}
        foreach ($it in $improvementsJson.items) { $jsonImpLookup[(ItemKey $it)] = ToCanonString (Canonicalize $it) }
        $htmlImpLookup = @{}
        foreach ($it in $htmlImprovements.items) { $htmlImpLookup[(ItemKey $it)] = ToCanonString (Canonicalize $it) }

        foreach ($k in $jsonImpLookup.Keys) {
            if (-not $htmlImpLookup.ContainsKey($k)) {
                $improvementsMismatches += "missing in HTML: $k"
                continue
            }
            if ($jsonImpLookup[$k] -ne $htmlImpLookup[$k]) {
                $improvementsMismatches += "differs: $k"
                $improvementsMismatches += "  JSON: $($jsonImpLookup[$k])"
                $improvementsMismatches += "  HTML: $($htmlImpLookup[$k])"
            }
        }
        foreach ($k in $htmlImpLookup.Keys) {
            if (-not $jsonImpLookup.ContainsKey($k)) {
                $improvementsMismatches += "missing in JSON: $k"
            }
        }

        # Top-level metadata sanity check.
        foreach ($field in 'version','source','fetched_at','note') {
            if ($improvementsJson.$field -ne $htmlImprovements.$field) {
                $improvementsMismatches += ("metadata '$field' differs: JSON='{0}' HTML='{1}'" -f $improvementsJson.$field, $htmlImprovements.$field)
            }
        }
    }
}
else {
    Write-Host "NOTE: data/improvements.json not present; skipping improvements check"
}

# ---------------- Report ----------------

$totalMismatches = $tasksMismatches.Count + $improvementsMismatches.Count

if ($tasksMismatches.Count -gt 0) {
    Write-Host "FAIL [tasks]: $($tasksMismatches.Count) issue(s)"
    foreach ($line in $tasksMismatches | Select-Object -First 30) { Write-Host "  $line" }
    if ($tasksMismatches.Count -gt 30) { Write-Host "  ... $($tasksMismatches.Count - 30) more" }
}
else {
    Write-Host "OK [tasks]: $($tasksJson.Count) tasks match between data/tasks.json and guide.html"
}

if (Test-Path $improvementsJsonPath) {
    if ($improvementsMismatches.Count -gt 0) {
        Write-Host "FAIL [improvements]: $($improvementsMismatches.Count) issue(s)"
        foreach ($line in $improvementsMismatches | Select-Object -First 30) { Write-Host "  $line" }
        if ($improvementsMismatches.Count -gt 30) { Write-Host "  ... $($improvementsMismatches.Count - 30) more" }
    }
    else {
        Write-Host "OK [improvements]: $improvementsCount items match between data/improvements.json and guide.html"
    }
}

if ($totalMismatches -gt 0) { exit 1 }
exit 0
