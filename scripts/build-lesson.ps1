# build-lesson.ps1 - md -> docx for a chapter, then quantitative self-check.
#
# Naming rule (user 2026-10-24): the printed docx must carry student, subject and
# chapter, because printed copies lose their folder context:
#     <student><subject>_<chapter>_<kit>.docx
#     e.g. studentA物理_已学大题专题_教案.docx
# The md source keeps the short name (学案.md / 教案.md / 课后作业.md).
#
# Checks (all numbers, no eyeballing):
#   * docx exists and is non-empty
#   * word/document.xml math segments  (m:oMath count)
#   * word/media image count vs md image references
#   * md has no TODO / 待补充 / (略) placeholders
#   * stale old-named docx (<kit>.docx) is reported
#
# ASCII-only labels; Chinese is runtime data. Save as UTF-8 WITH BOM.
#
# Usage: build-lesson.ps1 "C:\...\studentA\物理\已学大题专题"
#        build-lesson.ps1 -ChapterDir "C:\...\studentA\物理\已学大题专题"

param(
  [string]$ChapterDir = '',
  [string[]]$Kit = @()
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ChapterDir)) { 'FATAL: pass -ChapterDir <chapter dir>'; exit 2 }
if (-not (Test-Path -LiteralPath $ChapterDir)) { "FATAL: dir not found: $ChapterDir"; exit 2 }

$pandoc = Get-Command pandoc -ErrorAction SilentlyContinue
if (-not $pandoc) { 'FATAL: pandoc not found in PATH'; exit 2 }

$resolved = (Resolve-Path -LiteralPath $ChapterDir).Path
$chapter    = Split-Path $resolved -Leaf
$subjectDir = Split-Path $resolved -Parent
$subject    = Split-Path $subjectDir -Leaf
$stuDir     = Split-Path $subjectDir -Parent
$student    = Split-Path $stuDir -Leaf
$prefix = "$student$subject"
if ([string]::IsNullOrWhiteSpace($prefix) -or [string]::IsNullOrWhiteSpace($student)) { $prefix = $chapter }

if (-not $Kit -or $Kit.Count -eq 0) { $Kit = @('学案','教案','课后作业') }
$kit = $Kit
$figsDir = Join-Path $resolved 'figs'
$resourcePath = $resolved
if (Test-Path -LiteralPath $figsDir) { $resourcePath = $resolved + ';' + $figsDir }

$rows = @()
$fail = 0

foreach ($k in $kit) {
  $md   = Join-Path $resolved ($k + '.md')
  $docx = Join-Path $resolved ($prefix + '_' + $chapter + '_' + $k + '.docx')

  if (-not (Test-Path -LiteralPath $md)) {
    $rows += [pscustomobject]@{ Kit = $k; Status = 'SKIP'; Detail = 'no .md source'; File = (Split-Path $docx -Leaf) }
    continue
  }

  & pandoc -f markdown -t docx --resource-path="$resourcePath" -o $docx $md 2>&1 | Out-Null
  if (-not (Test-Path -LiteralPath $docx) -or (Get-Item -LiteralPath $docx).Length -eq 0) {
    $rows += [pscustomobject]@{ Kit = $k; Status = 'FAIL'; Detail = 'pandoc produced nothing'; File = (Split-Path $docx -Leaf) }
    $fail++
    continue
  }

  $mdText  = [System.IO.File]::ReadAllText($md)
  $imgRefs = ([regex]::Matches($mdText, '!\[[^\]]*\]\([^\)]+\)')).Count
  $mdMath  = [int]([regex]::Matches($mdText, '\$').Count / 2)
  $todo    = ([regex]::Matches($mdText, 'TODO|待补充|（略）|\(略\)')).Count

  $tmp = Join-Path $env:TEMP ('docxchk-' + [guid]::NewGuid().ToString('N'))
  $oMath = 0
  $media = 0
  try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($docx, $tmp)
    $docXml = Join-Path $tmp 'word\document.xml'
    if (Test-Path -LiteralPath $docXml) {
      $oMath = ([regex]::Matches([System.IO.File]::ReadAllText($docXml), '<m:oMath')).Count
    }
    $mediaDir = Join-Path $tmp 'word\media'
    if (Test-Path -LiteralPath $mediaDir) { $media = @(Get-ChildItem -LiteralPath $mediaDir -File).Count }
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }

  $status = 'PASS'
  $detail = "oMath=$oMath media=$media mdImg=$imgRefs mdMath=$mdMath"
  if ($imgRefs -gt 0 -and $media -lt $imgRefs) { $status = 'WARN'; $detail += ' IMAGES_LOST' }
  if ($mdMath -gt 0 -and $oMath -eq 0)        { $status = 'WARN'; $detail += ' FORMULA_LOST' }
  if ($todo -gt 0)                            { $status = 'WARN'; $detail += (' PLACEHOLDER=' + $todo) }
  if ($status -ne 'PASS') { $fail++ }

  $rows += [pscustomobject]@{ Kit = $k; Status = $status; Detail = $detail; File = (Split-Path $docx -Leaf) }
}

$stale = @()
foreach ($k in $kit) {
  $old = Join-Path $resolved ($k + '.docx')
  if (Test-Path -LiteralPath $old) { $stale += (Split-Path $old -Leaf) }
}

"CHAPTER: $chapter"
"PREFIX : $prefix"
$rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Output
if ($stale.Count -gt 0) { 'STALE  : old-named docx present -> ' + ($stale -join ', ') }
if ($fail -gt 0) { "RESULT: $fail kit(s) need attention"; exit 1 }
'RESULT: all PASS'
exit 0
