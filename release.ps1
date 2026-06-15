# release.ps1 — Blacklist by Vovo release helper
# Usage:  .\release.ps1 1.0.0
# This script bumps the TOC version, commits, tags, and pushes.
# GitHub Actions then auto-publishes the new version to CurseForge.

param(
    [Parameter(Mandatory, HelpMessage="Version number, e.g. 1.0.1")]
    [string]$Version
)

$ErrorActionPreference = "Stop"
$addonDir = $PSScriptRoot

Write-Host ""
Write-Host "==> Releasing Blacklist by Vovo v$Version" -ForegroundColor Cyan

# ── 1. Bump version in TOC ────────────────────────────────────────────────
$toc = Join-Path $addonDir "blacklist by Vovo.toc"
if (-not (Test-Path $toc)) {
    Write-Error "TOC file not found: $toc"
    exit 1
}
(Get-Content $toc) -replace '^## Version:.*', "## Version: $Version" | Set-Content $toc
Write-Host "  [1/4] TOC version updated to $Version" -ForegroundColor Green

# ── 2. Stage all changes ──────────────────────────────────────────────────
Set-Location $addonDir
git add .
Write-Host "  [2/4] Changes staged" -ForegroundColor Green

# ── 3. Commit + tag ───────────────────────────────────────────────────────
git commit -m "release: v$Version"
git tag "v$Version"
Write-Host "  [3/4] Committed and tagged v$Version" -ForegroundColor Green

# ── 4. Push branch + tag ─────────────────────────────────────────────────
git push origin main
git push origin "v$Version"
Write-Host "  [4/4] Pushed to GitHub" -ForegroundColor Green

Write-Host ""
Write-Host "Done! GitHub Actions will package and publish v$Version to CurseForge." -ForegroundColor Cyan
Write-Host "Watch the progress at: https://github.com/Volodymyr-Bauzi/wow-blacklist-addon/actions"
Write-Host ""
