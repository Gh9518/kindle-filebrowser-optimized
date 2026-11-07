#!/bin/sh
# 启动网页文件管理器：切到插件目录 → 处理网络 → 后台启动 filebrowser → 就绪检测 → 回桌面显示 IP
# 【重要】filebrowser v2.63.23 是「无子命令直接启动服务器」，不能用 `serve` 子命令：
#         带 serve 会报 unknown command "serve" 立即退出，80 端口无人监听 → 浏览器 ERR_CONNECTION_REFUSED。

# KUAL 可能从任意目录调用，先切到插件目录，保证 ./filebrowser、./filebrowser.db、lib.sh 等相对路径有效
cd "$(dirname "$0")" || exit 1
. ./lib.sh

# 记录启动时的无线状态：0=飞行模式(无线关) 1=无线开
INIT=$(wireless_state)
echo "$INIT" > WIFI_STATE

# 若处于飞行模式：先关闭飞行模式，等待 3 秒让无线就绪
if [ "$INIT" = "0" ]; then
	lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null
	sleep 3
fi

# 保持屏幕常亮：避免 Kindle 自动锁屏休眠后系统关闭 WiFi
lipc-set-prop -i com.lab126.powerd preventScreenSaver 1 2>/dev/null

# 核心程序缺失则先从 GitHub 下载（带屏幕进度）
[ ! -x ./filebrowser ] && { status "Downloading core..."; sh ./update.sh do >/dev/null 2>&1; }

# 结束残留进程：既释放 80 端口，也释放 filebrowser.db 的 BoltDB 写锁
# （残留进程持锁时新进程会 "Error: timeout" 启动失败，同样表现为无法访问）
# 同时清掉上一轮的自动退出守护，避免重复点「启动」后叠加多个定时器
for p in $(ps aux 2>/dev/null | grep [f]ilebrowser | awk '{print $2}'); do kill "$p" 2>/dev/null; done
for p in $(ps aux 2>/dev/null | grep -E '[i]dle.sh|[a]utoclose.sh' | awk '{print $2}'); do kill "$p" 2>/dev/null; done
sleep 2

# 放行 80 端口入站（部分 Kindle 固件默认拦截入站连接）
# 该规则同时作为「闲置退出」判定传输的计数器，故只在不存在时插入，避免重复堆积
if ! iptables -L INPUT -n 2>/dev/null | grep -q 'dpt:80'; then
	iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || \
		/sbin/iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null
fi

# 后台启动：v2.63.23 无 serve 子命令；--noauth 免登录（对已有 db 同样生效）；-d 显式指定数据库
# setsid 完全脱离终端 + 日志写文件，避免断网时后台进程向已关闭的 KUAL 管道写日志触发 SIGPIPE 崩溃
status "Starting..."; sleep 1
: > /tmp/filebrowser.log
detach ./filebrowser --noauth -a 0.0.0.0 -p 80 -r /mnt/us -d ./filebrowser.db \
	>/tmp/filebrowser.log 2>&1 </dev/null &

# 就绪检测：同时查 IPv4(/proc/net/tcp) 与 IPv6 双栈(/proc/net/tcp6)
# 端口 80 = 0x0050，状态 0A = LISTEN；-a 0.0.0.0 时 Go 监听落在 tcp6 表，只查 tcp 会误判
ready=0; i=0
while [ "$i" -lt 15 ]; do
	for tbl in /proc/net/tcp /proc/net/tcp6; do
		if awk 'NR>1 && $2 ~ /:0050$/ && $4=="0A"{f=1} END{exit !f}' "$tbl" 2>/dev/null; then
			ready=1; break
		fi
	done
	[ "$ready" = "1" ] && break
	sleep 1; i=$((i+1))
done

# 自动退出守护（本插件唯一的自动退出机制）：连续「AUTOCLOSE 秒」80 端口无传输即关闭。
# 守护常驻、每轮重读 AUTOCLOSE：菜单改档位即时生效（无需重启守护），AUTOCLOSE=0(从不)则空转待命不判定。
# 触发退出时由 idle.sh 调用 stop.sh，完整复用「按启动时飞行模式状态还原」的退出逻辑。
detach ./idle.sh >/dev/null 2>&1 </dev/null &

# 先刷新菜单（更新本机IP 标签、去掉飞行模式提示），供下次进入查看
sh ./genmenu.sh >/dev/null 2>&1

# 启动完成后自动返回 Kindle 桌面
lipc-send-event com.lab126.hal powerButtonPressed
sleep 2

# 在桌面用 eips 显示结果（eips 无中文字形，屏显提示统一用英文）
if [ "$ready" = "1" ]; then
	show_ip
else
	# 服务未监听：把 filebrowser 的真实报错显示到屏幕，便于定位根因
	err=$(grep -iE "error|fatal|timeout|panic|bind|address|cannot|failed" /tmp/filebrowser.log 2>/dev/null | tail -n 1 | cut -c1-40)
	[ -z "$err" ] && err="no listener on port 80"
	status "Err: $err"
	sleep 8; status ""
	show_ip
fi
