#!/bin/sh
# 启动网页文件管理器：处理飞行模式、保持屏幕常亮、开放端口、显示 IP、后台启动、自动退出
. ./lib.sh

# 记录启动时的无线状态：0=飞行模式(无线关) 1=无线开
INIT=$(wireless_state)
echo "$INIT" > WIFI_STATE

# 若处于飞行模式：先关闭飞行模式，等待 3 秒让无线就绪（仅在菜单点“打开网络并继续”后到这一步）
if [ "$INIT" = "0" ]; then
	lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null
	sleep 3
fi

# 保持屏幕常亮：避免 Kindle 自动锁屏休眠后系统关闭 WiFi（网络只在退出/自动退出时关闭）
lipc-set-prop -i com.lab126.powerd preventScreenSaver 1 2>/dev/null

# 核心程序缺失则先从 GitHub 下载（带屏幕进度）
[ ! -x ./filebrowser ] && { status "Downloading core..."; sh ./update.sh do >/dev/null 2>&1; }

# 开放 80 端口
iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null

# 后台启动 filebrowser（v2.63.23 用 serve 子命令）
# setsid 完全脱离终端 + 日志写文件：避免 Kindle 联网/断线时后台进程向已关闭的
# KUAL 管道写日志触发 SIGPIPE 而崩溃退出页面
detach ./filebrowser serve --noauth -a 0.0.0.0 -p 80 -r /mnt/us >/tmp/filebrowser.log 2>&1 </dev/null &

# 自动退出计时（默认 5 分钟）：到点执行与“关闭”相同的逻辑
AC=300; [ -f AUTOCLOSE ] && AC=$(cat AUTOCLOSE)
[ "$AC" -gt 0 ] 2>/dev/null && detach ./autoclose.sh "$AC" >/dev/null 2>&1 </dev/null &

# 先刷新菜单（更新本机IP 标签、去掉飞行模式提示），供下次进入查看
sh ./genmenu.sh >/dev/null 2>&1

# 启动完成后自动返回 Kindle 桌面
lipc-send-event com.lab126.hal powerButtonPressed
sleep 2

# 在桌面用 eips 显示本机IP（直写帧缓冲，持久可见；此处不重绘菜单，避免 KUAL 重新盖屏）
show_ip
