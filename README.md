# AI-Tutor-Workflow

家教备课用的提示词 + 4 个 PowerShell 脚本。输入一节课的知识点，输出三个 docx：学案（学生用）、教案（教师用）、课后作业（学生用）。

不需要服务器、不需要训练模型、不需要 API。

![三件套：学案 / 教案 / 课后作业](docs/images/three-kits.jpg)

## 产出

每个章节一个目录，三个文件：

```
{学生}/{科目}/{章节}/
├── 学案.md       → {学生}{科目}_{章节}_学案.docx
├── 教案.md       → {学生}{科目}_{章节}_教案.docx
├── 课后作业.md   → {学生}{科目}_{章节}_课后作业.docx
└── figs/
```

三份文档的内容规则：

| 文件 | 给谁 | 规则 |
|---|---|---|
| 学案 | 学生 | 只有题干和空白解题区；答案放文末附录，不含作业答案 |
| 教案 | 教师 | 只有答案和解析；≤ 200 行；公式一律行内 `$...$` |
| 课后作业 | 学生 | 不含答案，下次课对答案 |

![学案首页](docs/images/xuean-goals.jpg)

![教案内页](docs/images/plan-answers-only.jpg)

成品 docx 在 [examples/](examples/) 里，可以先打开看效果。

## 依赖

- Windows + PowerShell 5.1
- [pandoc](https://pandoc.org/)
- 任意 LLM（网页版够用）

## 使用

```powershell
# 建章节骨架
.\scripts\new-lesson.ps1 -Student studentA -Subject 物理 -Chapter 自由落体运动 -Root D:\家教
```

用 `prompts/` 下两份规格让模型生成三个 md，存进章节目录，然后：

```powershell
# 转 docx 并自检
.\scripts\build-lesson.ps1 -ChapterDir "D:\家教\studentA\物理\自由落体运动"
```

![自检输出](docs/images/terminal-pass.png)

`oMath` 是 docx 里的公式对象数，`media` 是内嵌图片数，`mdMath`/`mdImg` 是 md 里写的数量。对不上会 WARN。

转换加自检实测 0.4 秒（三次 0.50 / 0.44 / 0.43）。主要耗时在等模型出稿。

## 脚本

| 脚本 | 作用 |
|---|---|
| `new-lesson.ps1` | 建 `学生/科目/章节/figs` 目录，已存在则拒绝 |
| `build-lesson.ps1` | md 转 docx，自动加 `--resource-path`，打印自检 |
| `close-lesson.ps1` | 上完课清空章节文件、保留文件夹、写清理记录 |
| `lesson-health.ps1` | 检查目录结构、三件套齐全、空章节 |

## 目录

```
docs/        提示词全文、快速开始、复现教程、迭代记录、FAQ
prompts/     学案和教案的生成规格
templates/   备课主档、学生已知数据、pandoc 参考模板
scripts/     4 个脚本
examples/    物理《自由落体运动》三件套（md + docx）
```

## 已知限制

- 只支持 Windows
- 范本只有物理是完整的，数学可直接套用；化学、生物、文科缺
- 答案需要人工验算，脚本只检查格式不检查内容
- 仓库建于 2026-11，此前的迭代在本地非 git 环境，没有历史提交

## 贡献

补学科范本优先。格式要求和自查清单见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可

MIT
