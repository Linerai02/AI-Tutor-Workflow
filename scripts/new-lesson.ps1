# new-lesson.ps1 - 建章节骨架。默认建在桌面，缺失的目录和根文件一并补齐。
# 存成 UTF-8 带 BOM（PowerShell 5.1 会把无 BOM 的 UTF-8 当 ANSI 解析，中文直接乱码）。

param(
  [Parameter(Mandatory=$true)][string]$Student,
  [Parameter(Mandatory=$true)][string]$Subject,
  [Parameter(Mandatory=$true)][string]$Chapter,
  [string]$Root = [Environment]::GetFolderPath('Desktop'),
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$created = New-Object System.Collections.Generic.List[string]

$stuDir  = Join-Path $Root $Student
$subDir  = Join-Path $stuDir $Subject
$chapDir = Join-Path $subDir $Chapter
$figsDir = Join-Path $chapDir 'figs'

if ((Test-Path -LiteralPath $chapDir) -and -not $Force) {
  "FATAL: chapter already exists: $chapDir"
  "       use -Force to add missing subdirs only"
  exit 2
}

foreach ($d in @($stuDir, $subDir, $chapDir, $figsDir)) {
  if (-not (Test-Path -LiteralPath $d)) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    $created.Add($d)
  }
}

$tplDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates'
if (Test-Path -LiteralPath $tplDir) {
  foreach ($p in @(
    @('备课主档.template.md',    '备课主档.md'),
    @('学生已知数据.template.md','学生已知数据.md')
  )) {
    $tpl = Join-Path $tplDir $p[0]
    $dst = Join-Path $stuDir $p[1]
    if ((Test-Path -LiteralPath $tpl) -and -not (Test-Path -LiteralPath $dst)) {
      $t = [IO.File]::ReadAllText($tpl, [Text.Encoding]::UTF8)
      $t = $t.Replace('{学生名}', $Student).Replace('{学生代号}', $Student)
      [IO.File]::WriteAllText($dst, $t, (New-Object Text.UTF8Encoding($false)))
      $created.Add($dst)
    }
  }
} else {
  "WARN: templates not found: $tplDir"
}

"ROOT   : $Root"
if ($created.Count -gt 0) { $created | ForEach-Object { "CREATE : $_" } }
else { "CREATE : nothing (already complete)" }
""
"CHAPTER: $chapDir"
""
"NEXT:"
"  1. 把 学案.md / 教案.md / 课后作业.md 写进章节目录"
"  2. 图放 figs\，引用写 ![](figs/x.png)"
"  3. 转换: build-lesson.ps1 -ChapterDir `"$chapDir`""
