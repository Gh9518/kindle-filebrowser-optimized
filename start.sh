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

# 释放 80 端口：结束可能残留的旧 filebrowser 进程。
# 这是“显示 IP 但浏览器无法访问”的常见原因——上次未正常关闭导致端口仍被占用，新进程起不来。
for p in $(ps aux 2>/dev/null | grep [f]ilebrowser | awk '{print $2}'); do kill "$p" 2>/dev/null; done
sleep 1

# 开放 80 端口（Kindle 默认策略可能拦截入站连接，插入一条 ACCEPT 放行）
iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null

# 后台启动 filebrowser（v2.63.23 用 serve 子命令，--noauth 免登录）
# setsid 完全脱离终端 + 日志写文件：避免 Kindle 联网/断线时后台进程向已关闭的
# KUAL 管道写日志触发 SIGPIPE 而崩溃退出页面
status "Starting..."; sleep 1
detach ./filebrowser serve --noauth -a 0.0.0.0 -p 80 -r /mnt/us >/tmp/filebrowser.log 2>&1 </dev/null &

# 等待端口监听（最多约 15 秒），用于排查“显示 IP 但无法访问”
# /proc/net/tcp 中 local_address 形如 00000000:0050（端口 80 = 0x0050），state 0A = LISTEN
ready=0; i=0
while [ "$i" -lt 15 ]; do
	if awk 'NR>1 && $2 ~ /:0050$/ && $4=="0A"{f=1} END{exit !f}' /proc/net/tcp 2>/dev/null; then
		ready=1; break
	fi
	sleep 1; i=$((i+1))
done

# 自动退出计时（默认 5 分钟）：到点执行与“关闭”相同的逻辑
AC=300; [ -f AUTOCLOSE ] && AC=$(cat AUTOCLOSE)
[ "$AC" -gt 0 ] 2>/dev/null && detach ./autoclose.sh "$AC" >/dev/null 2>&1 </dev/null &

# 先刷新菜单（更新本机IP 标签、去掉飞行模式提示），供下次进入查看
sh ./genmenu.sh >/dev/null 2>&1

# 启动完成后自动返回 Kindle 桌面
lipc-send-event com.lab126.hal powerButtonPressed
sleep 2

# 在桌面用 eips 显示结果（eips 无中文字形，屏显提示统一用英文）
if [ "$ready" = "1" ]; then
	show_ip
else
	# 服务未监听：把 filebrowser 的真实报错显示到屏幕，便于定位“无法访问”的根因
	# （如端口被占、二进制无法在本题设备执行、缺少运行环境等）
	err=$(tail -n 1 /tmp/filebrowser.log 2>/dev/null | cut -c1-36)
	[ -z "$err" ] && err="not started (empty log)"
	status "Err: $err"
	sleep 8; status ""
	show_ip
fi
