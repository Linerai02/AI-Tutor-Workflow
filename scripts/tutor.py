#!/usr/bin/env python3
"""AI-Tutor-Workflow 跨平台命令行。

Windows / macOS / Linux 都能用，只依赖 Python 3.8+ 和 pandoc。
与 PowerShell 版脚本功能一致：

    python tutor.py new  -s studentA -b 物理 -c 自由落体运动
    python tutor.py build -d ~/Desktop/studentA/物理/自由落体运动
    python tutor.py close -d <章节目录> [--dry-run]
    python tutor.py health [--root ~/Desktop]

路径一律可以用 ~。
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import zipfile
from datetime import datetime
from pathlib import Path

KITS = ("学案", "教案", "课后作业")
SUBJECTS = {"数学", "物理", "化学", "英语", "语文", "生物", "政治", "历史", "地理"}
NON_SUBJECT = {"资料", "课后反馈", "figs", "images"}
PKG = Path(__file__).resolve().parent.parent
TPL = PKG / "templates"


def say(*args):
    print(*args)


def setup_stdout():
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8", errors="replace")
            except Exception:
                pass


def default_root():
    desktop = Path.home() / "Desktop"
    return desktop if desktop.is_dir() else Path.home()


def resolve(p):
    return Path(p).expanduser().resolve()


# ---------------------------------------------------------------- new
def cmd_new(a):
    root = resolve(a.root) if a.root else default_root()
    stu, sub = root / a.student, root / a.student / a.subject
    chap = sub / a.chapter
    figs = chap / "figs"

    if chap.exists() and not a.force:
        say(f"FATAL: chapter already exists: {chap}")
        say("       use --force to add missing subdirs only")
        return 2

    created = []
    for d in (stu, sub, chap, figs):
        if not d.is_dir():
            d.mkdir(parents=True)
            created.append(d)

    if TPL.is_dir():
        for tname, dstname in (("备课主档.template.md", "备课主档.md"),
                               ("学生已知数据.template.md", "学生已知数据.md")):
            tpl, dst = TPL / tname, stu / dstname
            if tpl.is_file() and not dst.exists():
                text = tpl.read_text(encoding="utf-8")
                text = text.replace("{学生名}", a.student).replace("{学生代号}", a.student)
                dst.write_text(text, encoding="utf-8")
                created.append(dst)
    else:
        say(f"WARN: templates not found: {TPL}")

    say(f"ROOT   : {root}")
    if created:
        for c in created:
            say(f"CREATE : {c}")
    else:
        say("CREATE : nothing (already complete)")
    say("")
    say(f"CHAPTER: {chap}")
    say("")
    say("NEXT:")
    say("  1. 把 学案.md / 教案.md / 课后作业.md 写进章节目录")
    say("  2. 图放 figs/，引用写 ![](figs/x.png)")
    say(f'  3. 转换: python tutor.py build -d "{chap}"')
    return 0


# ---------------------------------------------------------------- build
def cmd_build(a):
    chap = resolve(a.chapter)
    if not chap.is_dir():
        say(f"FATAL: dir not found: {chap}")
        return 2
    if not shutil.which("pandoc"):
        say("FATAL: pandoc not found in PATH")
        return 2

    kits = a.kit or list(KITS)
    prefix = f"{chap.parent.parent.name}{chap.parent.name}"
    figs = chap / "figs"
    resource = str(chap) + (os.pathsep + str(figs) if figs.is_dir() else "")

    rows, fail = [], 0
    for k in kits:
        md, docx = chap / f"{k}.md", chap / f"{prefix}_{chap.name}_{k}.docx"
        if not md.is_file():
            rows.append((k, "SKIP", "no .md source", docx.name))
            continue

        subprocess.run(
            ["pandoc", "-f", "markdown", "-t", "docx",
             f"--resource-path={resource}", "-o", str(docx), str(md)],
            capture_output=True,
        )
        if not docx.is_file() or docx.stat().st_size == 0:
            rows.append((k, "FAIL", "pandoc produced nothing", docx.name))
            fail += 1
            continue

        text = md.read_text(encoding="utf-8", errors="replace")
        img_refs = len(re.findall(r"!\[[^\]]*\]\([^)]+\)", text))
        md_math = text.count("$") // 2
        todo = len(re.findall(r"TODO|待补充|（略）|\(略\)", text))

        omath = media = 0
        with zipfile.ZipFile(docx) as z:
            names = z.namelist()
            if "word/document.xml" in names:
                xml = z.read("word/document.xml").decode("utf-8", "replace")
                omath = xml.count("<m:oMath")
            media = sum(1 for n in names if n.startswith("word/media/"))

        status = "PASS"
        detail = f"oMath={omath} media={media} mdImg={img_refs} mdMath={md_math}"
        if img_refs > 0 and media < img_refs:
            status, detail = "WARN", detail + " IMAGES_LOST"
        if md_math > 0 and omath == 0:
            status, detail = "WARN", detail + " FORMULA_LOST"
        if todo > 0:
            status, detail = "WARN", detail + f" PLACEHOLDER={todo}"
        if status != "PASS":
            fail += 1
        rows.append((k, status, detail, docx.name))

    say(f"CHAPTER: {chap.name}")
    say(f"PREFIX : {prefix}")
    say("")
    widths = [max(len(str(r[i])) for r in rows) for i in range(4)] if rows else [0] * 4
    for r in rows:
        say("  ".join(str(r[i]).ljust(widths[i]) for i in range(4)))

    stale = [f"{k}.docx" for k in kits if (chap / f"{k}.docx").is_file()]
    if stale:
        say(f"STALE  : old-named docx present -> {', '.join(stale)}")
    say("")
    if fail:
        say(f"RESULT: {fail} kit(s) need attention")
        return 1
    say("RESULT: all PASS")
    return 0


# ---------------------------------------------------------------- close
def cmd_close(a):
    chap = resolve(a.chapter)
    if not chap.is_dir():
        say(f"FATAL: dir not found: {chap}")
        return 2

    files = sorted(p for p in chap.rglob("*") if p.is_file())
    if not files:
        say(f"NOTHING TO DO: {chap.name} has no files")
        return 0

    stu, sub = chap.parent.parent, chap.parent
    say(f"{stu.name} / {sub.name} / {chap.name} : {len(files)} files")
    for f in files:
        say("  - " + str(f.relative_to(chap)))

    if a.dry_run:
        say("DRY RUN: nothing deleted")
        return 0

    for f in files:
        f.unlink()
    say(f"DELETED: {len(files)} files under {chap} (folders kept)")

    data = stu / "学生已知数据.md"
    entry = f"- {datetime.now():%Y-%m-%d %H:%M} 清理 {sub.name}/{chap.name}（{len(files)} 个文件，不备份）"
    if data.is_file():
        text = data.read_text(encoding="utf-8").rstrip()
        text = (text + "\n" + entry + "\n") if "## 清理记录" in text else (
            text + "\n\n## 清理记录\n" + entry + "\n")
        data.write_text(text, encoding="utf-8")
        say(f"RECORDED : {data}")
    else:
        say(f"WARN: 学生已知数据.md not found under {stu}; cleanup not recorded")
    return 0


# ---------------------------------------------------------------- health
def cmd_health(a):
    root = resolve(a.root) if a.root else default_root()
    ignore = set(a.ignore or [])
    if not root.is_dir():
        say(f"FATAL: root not found: {root}")
        return 2

    issues = []
    students = sorted(d for d in root.iterdir()
                      if d.is_dir() and d.name not in NON_SUBJECT and d.name not in ignore)
    say(f"ROOT: {root}")
    say(f"STUDENTS: {len(students)}")
    say("")

    for stu in students:
        say(f"STUDENT: {stu.name}")
        names = [p.name for p in stu.iterdir() if p.is_file()]
        if not any("备课主档" in n for n in names):
            issues.append(f"{stu.name}: missing 备课主档.md")
        if not any("学生已知数据" in n for n in names):
            issues.append(f"{stu.name}: missing 学生已知数据.md")

        subs = sorted(d for d in stu.iterdir() if d.is_dir())
        subjects = [d for d in subs if d.name in SUBJECTS]
        misc = [d for d in subs if d.name not in SUBJECTS and d.name not in NON_SUBJECT]

        if not subjects:
            say("  STRUCT: no subject layer")
            issues.append(f"{stu.name}: no subject layer, {len(misc)} dirs at chapter level")
            continue

        say(f"  STRUCT: OK ({len(subjects)} subjects)")
        if misc:
            say("  STRUCT: orphan dirs -> " + ", ".join(d.name for d in misc))
            issues.append(f"{stu.name}: orphan dirs -> " + ", ".join(d.name for d in misc))

        for s in subjects:
            chapters = sorted(d for d in s.iterdir() if d.is_dir() and d.name not in NON_SUBJECT)
            say(f"  SUBJECT: {s.name}  chapters={len(chapters)}")
            empty = 0
            for ch in chapters:
                files = [p for p in ch.rglob("*") if p.is_file()]
                local = [p.name for p in ch.iterdir() if p.is_file()]
                missing = [k for k in KITS
                           if not any(n == f"{k}.docx" or n.endswith(f"_{k}.docx") for n in local)]
                if not files:
                    say(f"    - {ch.name}: files=0  [EMPTY]")
                    empty += 1
                elif missing:
                    say(f"    - {ch.name}: files={len(files)}  [MISSING: "
                        + ", ".join(m + ".docx" for m in missing) + "]")
                    issues.append(f"{stu.name}/{s.name}/{ch.name}: incomplete kit -> "
                                  + ", ".join(missing))
                else:
                    say(f"    - {ch.name}: files={len(files)}  [OK]")
            if empty:
                say(f"    (empty chapter folders: {empty} - kept as progress markers)")
        say("")

    say(f"=== ISSUES: {len(issues)} ===")
    for i, x in enumerate(issues, 1):
        say(f"  {i}. {x}")
    return 0 if not issues else 1


# ---------------------------------------------------------------- main
def main():
    setup_stdout()
    p = argparse.ArgumentParser(prog="tutor", description="AI-Tutor-Workflow CLI")
    sub = p.add_subparsers(dest="cmd", required=True)

    n = sub.add_parser("new", help="建章节骨架（默认建在桌面）")
    n.add_argument("-s", "--student", required=True)
    n.add_argument("-b", "--subject", required=True)
    n.add_argument("-c", "--chapter", required=True)
    n.add_argument("-r", "--root", default=None, help="根目录，默认桌面")
    n.add_argument("--force", action="store_true", help="只补缺失子目录")
    n.set_defaults(func=cmd_new)

    b = sub.add_parser("build", help="md 转 docx 并自检")
    b.add_argument("-d", "--chapter", required=True, help="章节目录")
    b.add_argument("-k", "--kit", nargs="*", default=None, help="只处理指定文件类型")
    b.set_defaults(func=cmd_build)

    c = sub.add_parser("close", help="清空章节文件，保留文件夹")
    c.add_argument("-d", "--chapter", required=True)
    c.add_argument("--dry-run", action="store_true")
    c.set_defaults(func=cmd_close)

    h = sub.add_parser("health", help="检查目录结构与三件套完整性")
    h.add_argument("-r", "--root", default=None)
    h.add_argument("--ignore", nargs="*", default=None)
    h.set_defaults(func=cmd_health)

    a = p.parse_args()
    sys.exit(a.func(a))


if __name__ == "__main__":
    main()
