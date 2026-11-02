# close-lesson.ps1 - clear a finished chapter: delete its files, keep folders,
# record the cleanup in 学生已知数据.md.
#
# User decision 2026-10-23: NO backup. "清理就是为了腾空间，备份等于没清。"
# This supersedes the 2026-09-26 "backup before delete" rule.
#
# Safety: the exact file list is printed before deleting. Use -DryRun to preview.
#
# ASCII-only labels; Chinese is runtime data. Save as UTF-8 WITH BOM.
#
# Usage:
#   close-lesson.ps1 -ChapterDir "<chapter dir>"
#   close-lesson.ps1 -ChapterDir "<chapter dir>" -DryRun

param(
  [Parameter(Mandatory=$true)][string]$ChapterDir,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ChapterDir = (Resolve-Path -LiteralPath $ChapterDir).Path

$chapter    = Split-Path $ChapterDir -Leaf
$subjectDir = Split-Path $ChapterDir -Parent
$subject    = Split-Path $subjectDir -Leaf
$stuDir     = Split-Path $subjectDir -Parent
$student    = Split-Path $stuDir -Leaf

$files = @(Get-ChildItem -LiteralPath $ChapterDir -Recurse -File -ErrorAction SilentlyContinue)
if ($files.Count -eq 0) { "NOTHING TO DO: $chapter has no files"; exit 0 }

"$student / $subject / $chapter : $($files.Count) files"
foreach ($f in $files) { '  - ' + $f.FullName.Substring($ChapterDir.Length).TrimStart('\') }

if ($DryRun) { 'DRY RUN: nothing deleted'; exit 0 }

foreach ($f in $files) { Remove-Item -LiteralPath $f.FullName -Force }
"DELETED: $($files.Count) files under $ChapterDir (folders kept)"

$dataFile = Join-Path $stuDir '学生已知数据.md'
if (Test-Path -LiteralPath $dataFile) {
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
  $entry = "- $stamp 清理 $subject/$chapter（$($files.Count) 个文件，不备份）"
  $existing = [System.IO.File]::ReadAllText($dataFile)
  if ($existing -match '## 清理记录') {
    $existing = $existing.TrimEnd() + "`r`n" + $entry + "`r`n"
  } else {
    $existing = $existing.TrimEnd() + "`r`n`r`n## 清理记录`r`n" + $entry + "`r`n"
  }
  [System.IO.File]::WriteAllText($dataFile, $existing, (New-Object System.Text.UTF8Encoding($true)))
  "RECORDED : $dataFile"
} else {
  "WARN: 学生已知数据.md not found under $student; cleanup not recorded"
}
exit 0
