# 更新日志 / Changelog

> 版本号规则：大版本为功能级重构；**小更新（如本次）递增小版本号（2.0 → 2.0.1 → 2.0.2 …）**，便于区分小幅优化与重大变更。

## v2.0.1（2026-11-05）

- 新增**首次运行语言选择**：无语言记录时弹出双语「选择语言 / Select language」菜单（中文 / English），选定后以该语言显示，降低非中文用户使用门槛。
- 菜单内新增「语言 / Language」项，可随时重新选择界面语言（等效于 `LANG` 文件）。
- 版本号升至 **2.0.1**（小更新递增小版本号）。
- 致谢与参考：书伴（BookFere）文章 [《File Browser：便捷地管理 Kindle 中的文件》](https://bookfere.com/post/823.html)（本插件原始思路来源，由 Sparkle 投稿）；核心程序 filebrowser（作者 Henrique Dias，现由 Oleg Lobanov 维护）。

## v2.0（2026-11-05）

- 插件版本号升至 **2.0**（与核心 filebrowser 版本号区分），`config.xml`、`VERSION`、`menu.json` 标题同步。
- 修复语言显示：中文系统默认中文菜单，其它系统英文；新增 `LANG` 文件手动切换中/英。
- 修复「自动退出」需点两次才生效的竞态：重建 `menu.json` 提前到屏显之前，一次点击即生效。
- 启动 / 关闭执行完返回 Kindle 桌面；本机 IP 在桌面持久显示（eips 位置 8,1）。
- 重写中英文 README 与更新日志；独立 GitHub 仓库发布。
- 致谢与参考：书伴（BookFere）文章 [《File Browser：便捷地管理 Kindle 中的文件》](https://bookfere.com/post/823.html)（本插件原始思路来源，由 Sparkle 投稿）；核心程序 filebrowser（作者 Henrique Dias，现由 Oleg Lobanov 维护）。

## v1.x 摘要 / v1.x summary

- v1.1：内置核心程序（v2.63.23）、中文菜单、关闭随退出、IP 显示。
- 后续各版：更新进度提示、IP 位置与样式调整、飞行模式状态机、锁屏不断网、菜单动态刷新（一次点击刷新勾选）等持续打磨。
- 自动退出时间选项定型为「从不 / 05分 / 15分 / 30分 / 60分」（默认 05分）。
