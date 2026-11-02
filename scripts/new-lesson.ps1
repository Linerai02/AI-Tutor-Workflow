# new-lesson.ps1 - create a tutoring lesson skeleton (never overwrites).
#
# Convention (AGENTS.md 2026-09-18, unified 2026-10-23):
#   <root>\家教XX\<subject>\<chapter>\{学案,教案,课后作业}.md + figs\
#   <root>\家教XX\备课主档.md + 学生已知数据.md
#
# No generic wheel exists for this private folder convention; it is glue only.
# ASCII-only labels; Chinese is runtime data. Save this file as UTF-8 WITH BOM
# (PowerShell 5.1 parses BOM-less UTF-8 as ANSI -> mojibake).
#
# Usage:
#   new-lesson.ps1 -Student studentA -Subject 数学 -Chapter 一元二次方程
#   new-lesson.ps1 ... -Force     # only add missing subdirs

param(
  [Parameter(Mandatory=$true)][string]$Student,
  [Parameter(Mandatory=$true)][string]$Subject,
  [Parameter(Mandatory=$true)][string]$Chapter,
  [string]$Root = (Get-Location).Path,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$stuDir = Join-Path $Root $Student
if (-not (Test-Path -LiteralPath $stuDir)) { Write-Output "FATAL: student dir not found: $stuDir"; exit 2 }

$main = @(Get-ChildItem -LiteralPath $stuDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '备课主档' })
$data = @(Get-ChildItem -LiteralPath $stuDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '学生已知数据' })
if ($main.Count -eq 0) { "WARN: no 备课主档.md under $Student" }
if ($data.Count -eq 0) { "WARN: no 学生已知数据.md under $Student" }

$subDir  = Join-Path $stuDir $Subject
$chapDir = Join-Path $subDir $Chapter
$figsDir = Join-Path $chapDir 'figs'

if ((Test-Path -LiteralPath $chapDir) -and -not $Force) {
  "FATAL: chapter already exists: $chapDir"
  "       use -Force only to add missing subdirs"
  exit 2
}

foreach ($d in @($subDir, $chapDir, $figsDir)) {
  if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

"OK: $chapDir"
"OK: $figsDir"
""
"NEXT:"
"  1. create 3 sources in the chapter dir: 学案.md / 教案.md / 课后作业.md"
"  2. put images in figs\ and reference them relatively (![](figs/x.png))"
"  3. build: build-lesson.ps1 -ChapterDir `"$chapDir`""
