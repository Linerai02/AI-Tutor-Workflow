---
name: 报告问题 / Bug report
about: 跑不通、转换出错、自检不通过
title: '[Bug] '
labels: bug
assignees: ''
---

## 卡在哪一步

- [ ] 装 pandoc / 环境准备
- [ ] `new-lesson.ps1` 建目录
- [ ] 让模型出三份 md
- [ ] `build-lesson.ps1` 转 docx
- [ ] docx 打出来效果不对
- [ ] 其他

## 实际发生了什么

<!-- 把终端输出、报错、或截图贴在这里。build-lesson.ps1 的完整输出最有用 -->

```
（粘贴 build-lesson.ps1 的 RESULT 部分）
```

## 期望发生什么

<!-- 一两句 -->

## 环境

| 项 | 值 |
|---|---|
| 系统 | Windows 10 / 11 / 其他 |
| PowerShell | `$PSVersionTable.PSVersion` 的输出 |
| pandoc | `pandoc --version` 的第一行 |
| 学科 / 课题 | |

## 已经试过什么

<!-- 比如换过 --resource-path、换过编码、删了重装 -->

## 如果涉及公式或图片

- [ ] 我已确认 md 里公式用 `$...$` 包裹
- [ ] 我已确认图片路径是相对路径 `figs/x.png`
- [ ] 我已看 `docs/05-常见问题.md`
