# 更新日志 / Changelog

> 版本号规则：大版本为功能级重构；小更新在原 **2.0.1** 内累积，**不再单独递增小版本号**。

## v2.0.1（2026-11-05）

- **默认中文**：打开即以中文显示，无需任何配置；改为不判断系统语言（英文系统的 Kindle 也默认中文），非中文用户点菜单最后一项即可切换。
- **语言项移至菜单最后**：从菜单中部（原第 4 项）移到末尾（本机IP 之后），显示“将要切换到的目标语言”的**本名**：中文菜单显示 `English`（英文名称）、英文菜单显示 `中文`（中文名），便于辨识与修改。
- **标题固定为「网页文件管理器2」**（英文 `Web File Browser 2`），不再随版本号变动。
- **本机 IP 屏幕位置**：eips 12,3（改 `lib.sh` 的 `IP_ROW`/`IP_COL` 即全局生效）。
- **修复「启动后显示 IP 但浏览器 ERR_CONNECTION_REFUSED」（根因）**：用 qemu 实跑核心程序确认 —— filebrowser **v2.63.23 是「无子命令直接启动服务器」，不存在 `serve` 子命令**；旧 `start.sh` 用了 `./filebrowser serve ...`，程序报 `unknown command "serve"` 立即退出，80 端口根本无人监听，而 IP 由脚本单独显示，于是出现“看似启动成功却拒绝连接”。已改为 `./filebrowser --noauth -a 0.0.0.0 -p 80 -r /mnt/us -d ./filebrowser.db`（去掉 `serve`、显式指定数据库）。
- **就绪检测修正**：`-a 0.0.0.0` 时 Go 监听落在 IPv6 双栈表 `/proc/net/tcp6`，旧检测只查 IPv4 表 `/proc/net/tcp` 会永远误判为“未监听”；现同时轮询两张表。启动前先切到插件目录、清理残留进程（释放端口与数据库写锁），失败则屏幕显示 `Err: …`（取自 `/tmp/filebrowser.log`）便于定位。
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
