# Kindle 的 filebrowser 优化 2.0.1 版本 / Kindle filebrowser optimization 2.0.1

基于 [filebrowser](https://github.com/filebrowser/filebrowser) 的 Kindle（KUAL）网页文件管理器插件，可在手机、平板或电脑的浏览器中管理 Kindle 里的文件。本插件的原始方案与思路源自书伴（BookFere）文章 [《File Browser：便捷地管理 Kindle 中的文件》](https://bookfere.com/post/823.html)。核心程序已内置打包（v2.63.23，armv7），开箱即用，并支持在线更新。

> File Browser 已于 2026-09-01 归档，v2.63.23 为最后一个版本，后续不再有更新。

## 功能 / Features

- **启动 / 关闭**：默认监听 `http://<本机IP>:80`；运行时保持屏幕常亮，**仅退出或自动退出时才关闭网络**（锁屏不会断网）。执行完后返回 Kindle 桌面。
- **自动退出**：`从不 / 05分 / 15分 / 30分 / 60分`（默认 05分），到点执行与「关闭」完全相同的逻辑。一次点击即生效。
- **本机IP**：菜单内直接显示当前 IP；点击可在屏幕显示（eips 位置 10,2）。
- **更新核心程序**：先联网校验再选择更新，下载带实时进度。
- **飞行模式**：按「启动时」的网络状态还原（启动时为飞行模式则退出时重开）。
- **中英文菜单**：首次运行弹出双语「选择语言」菜单（中文 / English），选后即以该语言显示；菜单内「语言」项可随时重新选择。也可手动用 `LANG` 文件切换。

## 安装 / Install

1. 越狱并安装 KUAL / MRPI。
2. 将本文件夹（保持名为 `filebrowser`）放入 Kindle 的 `extensions/` 目录。
3. 打开 KUAL，即可看到「网页文件管理器 2.0.1」菜单。

## 使用 / Usage

- 首次打开会先出现「选择语言 / Select language」菜单，点 **中文** 或 **English** 即可；之后菜单以所选语言显示。
- 进入「网页文件管理器 2.0.1」→「启动」，屏幕显示本机 IP。
- 电脑浏览器访问 `http://<显示的IP>:80`，即可管理 `/mnt/us`（Kindle 根目录）下的文件。
- 「关闭」停止服务并（按需）还原飞行模式后返回桌面。

## 语言切换 / Language

- **首次运行**：打开 KUAL 会先出现双语「选择语言 / Select language」菜单，点 **中文** 或 **English** 即可选定界面语言（无需预知系统语言，降低使用门槛）。选定后生成 `LANG` 文件，之后均以该语言显示。
- **随时切换**：在菜单中点击「语言 / Language」项，可重新进入选择菜单。
- **手动切换（等效）**：在插件根目录（即 `extensions/filebrowser/`，与 `start.sh` 同级）新建名为 `LANG` 的文件，内容只写 `en`（英文）或 `zh`（中文）一行；保存后重启 KUAL 生效。删除该文件会再次触发首次语言选择。
- 说明：`LANG` 文件仅含 `en` 或 `zh` 一行文本；eips 屏上状态提示因字体不含中文字形，始终为英文。

## 菜单结构 / Menu

```
网页文件管理器 2.0.1
├ 启动（飞行模式下先提示「打开网络并继续 / 暂不启动」）
├ 关闭（按需还原飞行模式，返回桌面）
├ 自动退出：05分 → 从不 / 05分 / 15分 / 30分 / 60分
├ 语言（随时重新选择 中文 / English）
├ 更新核心程序（先校验，再选择 确认更新 / 暂不更新）
└ 本机IP: 192.168.x.x   ← 直接显示，点击可在屏幕显示 IP（eips 10,2）
```

## 脚本结构 / Structure

所有脚本共享 `lib.sh`，避免重复代码：

| 脚本 | 职责 / Role |
|------|------|
| `lib.sh` | 公共函数库（IP 获取、屏幕状态、语言判断等） |
| `genmenu.sh` | 按设置/更新状态生成 `menu.json`（含中英文与版本号） |
| `start.sh` | 启动（飞行模式处理、常亮、开端口、显示 IP、脱离终端启动） |
| `stop.sh` | 关闭：结束服务，按需还原飞行模式，返回桌面 |
| `ip.sh` | 屏幕显示本机 IP（位置见 `lib.sh` 的 `IP_ROW`/`IP_COL`） |
| `timeout.sh` | 设置自动退出时间（先重建菜单，确保一次点击即生效） |
| `autoclose.sh` | 定时退出计时器：到点调用 `stop.sh` |
| `setlang.sh` | 设置界面语言（写 `LANG` 并刷新菜单），供语言选择菜单调用 |
| `update.sh` | `check`=校验更新；`do`=下载安装 |

## 说明 / Notes

- 端口 80 已通过 `iptables` 放行；后台以 `setsid` 完全脱离终端并将日志写入 `/tmp/filebrowser.log`，避免联网/断线时崩溃。
- `eips` 帧缓冲字体不含中文字形，故屏上状态提示统一用英文；中文仅保留在 KUAL 菜单 UI。
- `AUTOCLOSE` 保存自动退出秒数（`0`=不退出）；`WIFI_STATE` 为运行时临时状态，请勿手动编辑。
- 修改 IP 显示位置：编辑 `lib.sh` 顶部的 `IP_ROW` / `IP_COL`（默认 10 / 2）。
- 升级核心版本后启动失败：可删除 `filebrowser.db` 重新「启动」，filebrowser 会自动重建配置。

## 致谢 / Acknowledgements

- 书伴（BookFere）文章：[《File Browser：便捷地管理 Kindle 中的文件》](https://bookfere.com/post/823.html) —— 本插件（由 Sparkle 投稿）的原始介绍与思路来源，特此致谢。
- 核心程序 [filebrowser](https://github.com/filebrowser/filebrowser)（作者 Henrique Dias，现由 Oleg Lobanov 维护；官方文档 <https://filebrowser.org/>）。
- 书伴（BookFere）的 KUAL / MRPI 越狱与插件框架教程。

---

本项目为独立仓库，与作者此前发布的其它项目分开维护。
