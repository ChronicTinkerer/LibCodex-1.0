# release.ps1 -- one-command release helper for LibCodex-1.0.
#
# Usage (from the repo root, in a PowerShell terminal):
#   .\release.ps1 "fix: NPCs catalog handles 0-id rows"
#   .\release.ps1 "fix: ..." -DryRun     # preview, no files touched, no git
#   .\release.ps1 "fix: ..." -NoPush     # bump + commit + tag locally only
#
# What it does:
#   1. Compute a YYMMDDHHMM stamp from the current local clock.
#   2. Rewrite "## Version:" in LibCodex-1.0.toc.
#   3. Rewrite "local LIB_MINOR = ..." in LibCodex-1.0.lua.
#   4. git add -A
#   5. git commit -m <message>
#   6. git tag -a <stamp> -m <stamp>     (annotated -- never lightweight)
#   7. git push origin HEAD
#   8. git push origin <stamp>
#   9. Print the GitHub Actions URL so you can watch the run.
#
# Notes:
#   * Vendored libraries (LibEditMode, LibStub) are NOT touched. The pattern
#     is specific to "local LIB_MINOR" so it can't accidentally match.
#   * If you've left unrelated edits in the working tree, they'll be picked
#     up by `git add -A` and rolled into the same commit. Use -DryRun first
#     when in doubt.
#   * If PowerShell blocks the script with an execution policy error, run
#     once in your shell:
#         Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#
# When copying this script to a new addon repo, edit the "Configuration"
# block below: AddonName, RepoOwner, and the FilesToBump list.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Message,

    [switch]$DryRun,

    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'

# ---------- Configuration (edit per addon when reusing this script) -------

$AddonName       = 'LibCodex-1.0'
$RepoOwner       = 'ChronicTinkerer'

# Versioning convention (changed 2026-05-05): we use sequential build
# numbers instead of YYMMDDHHMM stamps. The script reads the current
# version from the primary TOC ($PrimaryVersionFile) and increments by 1.
# If the file's version digit is 0 or missing, the counter starts at 1.
# Rationale: time-stamped versions go non-monotonic when builds happen
# from machines on different timezones (or when a sandbox runs UTC).
# Sequential is always strictly increasing, simpler to reason about.
# Caveat for already-published projects: when the new sequential value is
# numerically lower than the last published YYMMDDHHMM stamp, users on
# the old version won't auto-update. They have to update manually once,
# then auto-updates resume from the next bump.
$PrimaryVersionFile = 'LibCodex-1.0.toc'

# Each entry: a file at the repo root (relative to this script) plus the
# regex that finds the version-stamp digits. (?m) enables multiline so the
# ^ anchor matches each line. Group 1 is everything up to the digits and
# is preserved; \d+ is replaced with the new stamp.
# All flavor TOCs share one version stamp so users on any client see the
# same release at the same time. To add a new flavor: append the new TOC
# here, create the matching Data_<Flavor>/ folder, and add the flavor to
# tools/bake.py and tools/import-wago.py FLAVOR_* maps.
$FilesToBump = @(
    @{
        Path        = 'LibCodex-1.0.toc'
        Pattern     = '(?m)^(## Version:\s*)\d+'
        Description = 'Mainline TOC Version'
    },
    @{
        Path        = 'LibCodex-1.0_Mists.toc'
        Pattern     = '(?m)^(## Version:\s*)\d+'
        Description = 'Mists TOC Version'
    },
    @{
        Path        = 'LibCodex-1.0_TBC.toc'
        Pattern     = '(?m)^(## Version:\s*)\d+'
        Description = 'TBC TOC Version'
    },
    @{
        Path        = 'LibCodex-1.0.lua'
        Pattern     = '(?m)^(local LIB_MINOR\s*=\s*)\d+'
        Description = 'Library LIB_MINOR'
    }
)

# --------------------------------------------------------------------------

function Invoke-Git {
    param([Parameter(Mandatory = $true)][string[]]$Args)
    & git @Args
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Args -join ' ') failed (exit $LASTEXITCODE)"
    }
}

# Anchor everything to this script's directory so the script works no matter
# where the user cd'd from.
Push-Location $PSScriptRoot
try {
    # Read the current version from the primary TOC and increment by 1.
    # The pattern matches the same `## Version: N` line we'll then rewrite.
    if (-not (Test-Path $PrimaryVersionFile)) {
        throw "Primary version file not found: $PrimaryVersionFile"
    }
    $primaryContent = Get-Content $PrimaryVersionFile -Raw
    if ($primaryContent -match '(?m)^## Version:\s*(\d+)') {
        $currentVersion = [long]$matches[1]
    } else {
        $currentVersion = 0
    }
    $stamp = ($currentVersion + 1).ToString()

    Write-Host ''
    Write-Host "Release $AddonName -> $stamp" -ForegroundColor Cyan
    Write-Host "Commit message: $Message"     -ForegroundColor Cyan
    Write-Host ''

    # First pass: validate that every configured file exists and its pattern
    # matches exactly one place. Bail before touching anything if it doesn't.
    foreach ($entry in $FilesToBump) {
        if (-not (Test-Path $entry.Path)) {
            throw "Missing file: $($entry.Path)"
        }
        $content = Get-Content $entry.Path -Raw
        $matches = [regex]::Matches($content, $entry.Pattern)
        if ($matches.Count -eq 0) {
            throw "Pattern not found in $($entry.Path): $($entry.Pattern)"
        }
        if ($matches.Count -gt 1) {
            throw "Pattern matched $($matches.Count) places in $($entry.Path); expected exactly 1."
        }
        $oldLine = $matches[0].Value
        $newLine = $matches[0].Groups[1].Value + $stamp
        Write-Host "  $($entry.Description) [$($entry.Path)]"
        Write-Host "    before: $oldLine"
        Write-Host "    after:  $newLine"
    }
    Write-Host ''

    if ($DryRun) {
        Write-Host 'DRY RUN. No files modified, no git actions.' -ForegroundColor Yellow
        return
    }

    # Second pass: apply the edits. -NoNewline preserves the file's existing
    # trailing-newline behavior verbatim (so we don't churn EOL whitespace).
    foreach ($entry in $FilesToBump) {
        $content = Get-Content $entry.Path -Raw
        $updated = [regex]::Replace($content, $entry.Pattern, '${1}' + $stamp)
        Set-Content -Path $entry.Path -Value $updated -NoNewline
    }
    Write-Host 'Files updated.' -ForegroundColor Green
    Write-Host ''

    Invoke-Git @('add', '-A')
    Invoke-Git @('commit', '-m', $Message)
    # -a forces annotated. Lightweight tags trigger neither the workflow nor
    # VSCode's "Push (Follow Tags)" reliably -- this is the load-bearing flag.
    Invoke-Git @('tag', '-a', $stamp, '-m', $stamp)

    if ($NoPush) {
        Write-Host ''
        Write-Host "Tag $stamp created locally. -NoPush set; not pushing." -ForegroundColor Yellow
        Write-Host "When ready:" -ForegroundColor Yellow
        Write-Host "  git push origin HEAD"        -ForegroundColor Yellow
        Write-Host "  git push origin $stamp"      -ForegroundColor Yellow
        return
    }

    Invoke-Git @('push', 'origin', 'HEAD')
    Invoke-Git @('push', 'origin', $stamp)

    Write-Host ''
    Write-Host "Released $stamp" -ForegroundColor Green
    Write-Host "Watch the run: https://github.com/$RepoOwner/$AddonName/actions" -ForegroundColor Green
}
finally {
    Pop-Location
}
