#!/bin/sh
# 启动网页文件管理器：切到插件目录 → 处理网络 → 后台启动 filebrowser → 就绪检测 → 回桌面显示 IP
# 【重要】filebrowser v2.63.23 是「无子命令直接启动服务器」，不能用 `serve` 子命令：
#         带 serve 会报 unknown command "serve" 立即退出，80 端口无人监听 → 浏览器 ERR_CONNECTION_REFUSED。
# 【提速 v2.0.6】原先一串固定 sleep（飞行模式 3s / 清残留 2s / Starting 1s / 就绪检测每轮 1s）
#         全部改成「0.2 秒粒度轮询 + 条件满足立刻继续」，菜单重建移到后台，桌面重绘窗口内双写 eips；
#         启动到看见 IP 由约 6~10 秒缩短到约 2 秒。

# KUAL 可能从任意目录调用，先切到插件目录，保证 ./filebrowser、./filebrowser.db、lib.sh 等相对路径有效
cd "$(dirname "$0")" || exit 1
. ./lib.sh

# —— 轮询等待工具 ——
# wait_for <最多等几秒> <条件函数>：每轮 nap 一次（0.2s，老固件自动退化为 1s），条件成立立即返回 0；
# 用 NAP_N 把「秒」换算成轮询次数，不依赖 date，也不会在老固件上死循环。
wait_for() {
	[ -n "$NAP_T" ] || nap               # 仅首次探测短睡眠粒度（不额外等待）；条件已满足时 0 秒通过
	_max=$(( $1 * NAP_N )); shift
	_i=0
	while [ "$_i" -lt "$_max" ]; do
		"$@" && return 0
		nap; _i=$(( _i + 1 ))
	done
	return 1
}

has_ip() { [ "$(ip_addr)" != "未连接" ]; }
# 端口 80 = 0x0050，状态 0A = LISTEN；-a 0.0.0.0 时 Go 监听落在 tcp6 表，只查 tcp 会误判
port_ready() {
	for tbl in /proc/net/tcp /proc/net/tcp6; do
		awk 'NR>1 && $2 ~ /:0050$/ && $4=="0A"{f=1} END{exit !f}' "$tbl" 2>/dev/null && return 0
	done
	return 1
}
port_gone() { ! port_ready; }

# 记录启动时的无线状态：0=飞行模式(无线关) 1=无线开
INIT=$(wireless_state)
echo "$INIT" > WIFI_STATE

# 若处于飞行模式：打开无线后轮询等 IP，网络一就绪立刻继续；最多等 8 秒。
# 等不到也照常启动（此时屏幕显示 IP: ---，由 idle.sh 在联网后自动刷出真实 IP）
if [ "$INIT" = "0" ]; then
	lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null
	wait_for 8 has_ip
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
# 仅当 80 端口仍被旧进程占着才等它释放；无残留时 0 秒通过（不再固定 sleep 2）
wait_for 3 port_gone

# 放行 80 端口入站（部分 Kindle 固件默认拦截入站连接）
# 该规则同时作为「自动退出」判定传输的计数器，故只在不存在时插入，避免重复堆积
if ! iptables -L INPUT -n 2>/dev/null | grep -q 'dpt:80'; then
	iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || \
		/sbin/iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null
fi

# 后台启动：v2.63.23 无 serve 子命令；--noauth 免登录（对已有 db 同样生效）；-d 显式指定数据库
# setsid 完全脱离终端 + 日志写文件，避免断网时后台进程向已关闭的 KUAL 管道写日志触发 SIGPIPE 崩溃
status "Starting..."
: > /tmp/filebrowser.log
detach ./filebrowser --noauth -a 0.0.0.0 -p 80 -r /mnt/us -d ./filebrowser.db \
	>/tmp/filebrowser.log 2>&1 </dev/null &

# 就绪检测：IPv4(/proc/net/tcp) + IPv6 双栈(/proc/net/tcp6) 同时查，0.2 秒粒度轮询，命中即走
wait_for 12 port_ready && ready=1 || ready=0

# 自动退出守护（本插件唯一的自动退出机制）：连续「AUTOCLOSE 秒」80 端口无传输即关闭。
# 同时负责本机 IP 屏显刷新与联网门控；触发退出时由 idle.sh 调用 stop.sh 复用完整退出逻辑。
detach ./idle.sh >/dev/null 2>&1 </dev/null &

# 重建菜单只为「下次进入菜单」更新本机IP 标签，放到后台，不阻塞 IP 屏显
detach sh ./genmenu.sh >/dev/null 2>&1 </dev/null &

# 启动完成后自动返回 Kindle 桌面
lipc-send-event com.lab126.hal powerButtonPressed
sleep 1

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

# 部分固件桌面重绘较晚会覆盖首帧 eips；再补写一次，确保 IP 一定留在屏幕上
sleep 1
show_ip
