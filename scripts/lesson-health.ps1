# lesson-health.ps1 - READ-ONLY health check for the tutoring tree.
#
# Convention (AGENTS.md 2026-09-18 / 2026-09-26 / 2026-10-24):
#   <root>\家教XX\<subject>\<chapter>\{学案,教案,课后作业}.md
#   <root>\家教XX\<subject>\<chapter>\<student><subject>_<chapter>_<kit>.docx
#   <root>\家教XX\{备课主档.md, 学生已知数据.md}
#
# Kit completeness is judged by the docx (the printed deliverable); a missing md
# is reported as a note, not an issue, because the docx may be the only survivor.
#
# ASCII-only labels on purpose: PowerShell 5.1 parses .ps1 as ANSI, so中文
# literals here would be mojibake. Chinese directory names are runtime data.
#
# Usage: pwsh -File lesson-health.ps1 [-Root <dir>]

param(
  [string]$Root = (Get-Location).Path,
  [string[]]$Ignore = @()
)

$ErrorActionPreference = 'SilentlyContinue'
$Subjects  = @('数学','物理','化学','英语','语文','生物','政治','历史','地理')
$Kit       = @('学案','教案','课后作业')
$NonSubject = @('资料','课后反馈','figs','images')

$issues = New-Object System.Collections.Generic.List[string]

function Get-KitState([string]$dir) {
  $state = @{}
  $files = @(Get-ChildItem -LiteralPath $dir -File)
  foreach ($k in $Kit) {
    $md = @($files | Where-Object { $_.Name -eq "$k.md" })
    $dx = @($files | Where-Object { $_.Name -eq "$k.docx" -or $_.Name -like "*_$k.docx" })
    $state[$k] = @{ md = ($md.Count -gt 0); docx = ($dx.Count -gt 0) }
  }
  return $state
}

$students = @(Get-ChildItem -LiteralPath $Root -Directory | Where-Object { $NonSubject -notcontains $_.Name -and ($Ignore -notcontains $_.Name) } | Sort-Object Name)
"ROOT: $Root"
"STUDENTS: $($students.Count)"
""

foreach ($stu in $students) {
  "STUDENT: $($stu.Name)"
  $subs = @(Get-ChildItem -LiteralPath $stu.FullName -Directory)
  $subjectDirs = @($subs | Where-Object { $Subjects -contains $_.Name })
  $miscDirs    = @($subs | Where-Object { $Subjects -notcontains $_.Name -and $NonSubject -notcontains $_.Name })
  $rootFiles   = @(Get-ChildItem -LiteralPath $stu.FullName -File)

  if (-not ($rootFiles | Where-Object { $_.Name -match '备课主档' })) { $issues.Add("$($stu.Name): missing 备课主档.md") }
  if (-not ($rootFiles | Where-Object { $_.Name -match '学生已知数据' })) { $issues.Add("$($stu.Name): missing 学生已知数据.md") }

  $chapterSets = @{}
  if ($subjectDirs.Count -eq 0 -and $miscDirs.Count -gt 0) {
    "  STRUCT: MISSING_SUBJECT_LAYER (chapters hang directly under student)"
    $issues.Add("$($stu.Name): no subject layer, $($miscDirs.Count) dirs sit at chapter level")
    $chapterSets['(no-subject)'] = $miscDirs
  } else {
    "  STRUCT: OK ($($subjectDirs.Count) subjects)"
    foreach ($s in $subjectDirs) {
      $chapterSets[$s.Name] = @(Get-ChildItem -LiteralPath $s.FullName -Directory | Where-Object { $NonSubject -notcontains $_.Name })
    }
    if ($miscDirs.Count -gt 0) {
      $orphans = ($miscDirs | ForEach-Object { $_.Name }) -join ', '
      "  STRUCT: ORPHAN dirs -> $orphans"
      $issues.Add("$($stu.Name): orphan dirs -> $orphans")
    }
  }

  foreach ($subName in $chapterSets.Keys) {
    $chapters = @($chapterSets[$subName])
    "  SUBJECT: $subName  chapters=$($chapters.Count)"
    $emptyCount = 0
    foreach ($ch in $chapters) {
      $rec = @(Get-ChildItem -LiteralPath $ch.FullName -Recurse -File)
      $st  = Get-KitState $ch.FullName
      $missingDocx = @()
      $missingMd   = @()
      foreach ($k in $Kit) {
        if (-not $st[$k].docx) { $missingDocx += "$k.docx" }
        if (-not $st[$k].md)   { $missingMd += "$k.md" }
      }
      $line = "    - $($ch.Name): files=$($rec.Count)"
      if ($rec.Count -eq 0) {
        $line += '  [EMPTY]'
        $emptyCount++
      } elseif ($missingDocx.Count -gt 0) {
        $line += '  [MISSING: ' + ($missingDocx -join ', ') + ']'
        $issues.Add("$($stu.Name)/$subName/$($ch.Name): incomplete kit -> " + ($missingDocx -join ', '))
      } else {
        $line += '  [OK]'
        if ($missingMd.Count -gt 0) { $line += ' (md gone: ' + ($missingMd -join ', ') + ')' }
      }
      "    $line"

    }
    if ($emptyCount -gt 0) { "    (empty chapter folders: $emptyCount - kept as progress markers)" }
  }
  ""
}

"=== ISSUES: $($issues.Count) ==="
$i = 0
foreach ($x in $issues) { $i++; "  $i. $x" }
