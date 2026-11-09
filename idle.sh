#!/bin/sh
# 自动退出守护 —— 本插件「唯一」的自动退出机制
#   语义：连续「AUTOCLOSE 秒」80 端口无任何传输 → 执行与「关闭」完全相同的退出逻辑(sh ./stop.sh)。
#         因此会一并按需还原飞行模式、关闭屏幕常亮、返回桌面 —— 与手动「关闭」走同一条链路。
#   AUTOCLOSE 取值：0=从不（关闭此功能，守护空转待命、不判定）；60/180/300=1/3/5 分无传输即退出。
#   每轮重新读取 AUTOCLOSE：菜单里改档位后无需重启守护，即时生效。
#
# 本守护同时负责「本机 IP 屏显刷新」与「联网门控」：
#   - 启动时若尚未联网，ip_addr 返回「未连接」；一旦联网（拿到 IP）即主动刷新 eips 屏显，
#     解决「先无网后联网、IP 不刷新」的问题。IP 变化（DHCP 续租等）也会再次刷新。
#   - 空闲计时只统计「已联网」阶段的连续无传输：无网等待期不计入，联网瞬间重置基线，
#     因此不会把「无网等待」误算成空闲而到点自动退出。
#   - 【v2.0.7】无网络超时：连续 OFFLINE_MAX（默认 120 秒 / 2 分钟）始终拿不到 IP 时自动退出，
#     避免无网状态下无限等待、屏幕常亮空耗电。计时只在无网轮次累加，联网立即清零
#     （「无网→联网→再断网」会重新等满 2 分钟）。「从不」档位表示关闭自动退出，此超时同样不生效。
#     触发时与「无传输退出」一样调用 sh ./stop.sh，完整复用飞行模式还原逻辑。
# 判定「传输」：读 iptables 中 --dpt 80 规则的累计计数（只统计访问本服务的流量）。
#   Kindle 后台联网、以及「启动时飞行模式→临时开网 / 退出时还原」的 WiFi 开关都不会计入。
#   规则不可用时退化为统计非 lo 网卡字节并加阈值过滤噪声。
# 与飞行模式的关系：本脚本不直接动网络；触发时调用 stop.sh，由 stop.sh 依据启动时写入的
#   WIFI_STATE 决定是否重新开启飞行模式，保证「自动退出」与「手动关闭」还原行为一致。
#
# 【提速 v2.0.6】采样间隔 10s → 3s，且启动后首轮不等间隔立即检测一次：
#   「无网→联网」时 IP 屏显最多 3 秒即刷新（旧版要等满 10 秒一轮），自动退出精度也从 ±10s 提到 ±3s。
cd "$(dirname "$0")" || exit 1
. ./lib.sh

STEP=${IDLE_STEP:-3}                    # 采样间隔（秒）；测试时可用环境变量缩短
BOOT_WAIT=${IDLE_BOOT_WAIT:-3}          # 启动后等桌面重绘稳定再补写首帧（秒）
OFFLINE_MAX=${IDLE_OFFLINE_MAX:-120}    # 连续无网络多久后自动退出（秒，默认 2 分钟）；0=禁用；测试可覆盖
DEV_MIN=$(( 4096 * STEP / 10 ))         # fallback 噪声阈值按采样窗口等比缩放（原 10 秒窗口为 4096 字节）

# 读取当前「连续无传输多少秒后退出」；空/非法值默认 60（1 分），0 表示「从不」
read_secs() {
	s=$(cat AUTOCLOSE 2>/dev/null)
	case "$s" in
		''|*[!0-9]*) echo 60 ;;
		*) echo "$s" ;;
	esac
}

# 采样：优先返回 80 端口计数字符串（如 "12_1865"）；无该规则时返回 DEV<总字节>
# 用字符串比较而非数值，规避不同 iptables 版本把计数显示成 "2K" 这类后缀
sample() {
	c=$(iptables -L INPUT -n -v 2>/dev/null | awk '/dpt:80/{printf "%s_%s", $1, $2}')
	[ -n "$c" ] && { echo "$c"; return; }
	awk 'NR>2 && $1 !~ /lo:/ {s+=$2+$10} END{printf "DEV%d", s+0}' /proc/net/dev
}

# 判断两次采样之间是否发生了「传输」
changed() {
	case "$2" in
		DEV*)
			case "$1" in DEV*) ;; *) return 0 ;; esac
			[ "$1" = "$2" ] && return 1
			a=${1#DEV}; b=${2#DEV}
			[ $(( b - a )) -ge "$DEV_MIN" ] ;;
		*) [ "$1" != "$2" ] ;;   # 80 端口计数只要变化即算传输
	esac
}

# 服务是否仍在监听 80 端口（服务一关，本守护随即退出，避免重复执行 stop）
listening() {
	for tbl in /proc/net/tcp /proc/net/tcp6; do
		awk 'NR>1 && $2 ~ /:0050$/ && $4=="0A"{f=1} END{exit !f}' "$tbl" 2>/dev/null && return 0
	done
	return 1
}

# 等桌面重绘稳定（start.sh 会触发 powerButtonPressed 回桌面），避免首帧 eips 被覆盖；
# 此后首轮立即检测，联网后最快 3 秒就能刷出 IP
sleep "$BOOT_WAIT"
prev=$(sample)
quiet=0
offline=0                    # 连续「未联网」累计秒数；一旦联网立即清零
last_ip=""                   # 上一次显示的 IP；用于检测「无网→联网」/IP 变化以刷新屏显
first=1
while :; do
	# 首轮立即检测（不等 STEP），之后每轮先等待；
	# sleep 放在循环开头，保证下面未联网 / 「从不」等分支的 continue 不会跳过等待造成忙等
	if [ "$first" = "1" ]; then first=0; boot=1; else sleep "$STEP"; boot=0; fi
	listening || exit 0

	SECS=$(read_secs)            # 本轮档位（每轮重读，菜单改档即时生效）
	ip=$(ip_addr)

	# —— 无网络：等待联网，连续 OFFLINE_MAX 秒仍无网络则自动退出 ——
	# 「从不」(AUTOCLOSE=0) 表示关闭自动退出功能，此时无网超时同样不生效
	case "$ip" in
		未连接|"")
			quiet=0; prev=$(sample)   # 无网等待不计入空闲、刷新传输基线
			if [ "$last_ip" != "WAIT" ]; then status "Waiting for network..."; last_ip="WAIT"; fi
			[ "$boot" = "1" ] || offline=$(( offline + STEP ))   # 首轮与上一轮无间隔，不计入
			if [ "$SECS" -gt 0 ] 2>/dev/null && [ "$OFFLINE_MAX" -gt 0 ] && [ "$offline" -ge "$OFFLINE_MAX" ]; then
				status "No network $(( OFFLINE_MAX / 60 ))min, closing..."; sleep 1
				sh ./stop.sh          # 与手动「关闭」共用出口，完整还原飞行模式
				exit 0
			fi
			continue
			;;
	esac

	# —— 已联网：刷新屏显 ——
	offline=0                    # 网络恢复，无网等待重新计时
	if [ "$ip" != "$last_ip" ]; then
		# 【v2.0.8 修复：联网后 IP 一闪就消失】status "" 会用 42 个空格刷满整行，
		# 旧顺序把它放在 show_ip 之后，等于刚把 IP 写上就立刻擦掉；此后 IP 未变化
		# 便不再进入本分支重写，IP 就永久消失。改为「先清提示、再写 IP」，
		# 让 show_ip 成为最后一次写屏；联网瞬间常伴随 WiFi/框架重绘，再补写一帧。
		if [ "$last_ip" = "WAIT" ]; then
			status ""            # 先清掉“Waiting for network...”提示（刷整行空格）
			show_ip
			sleep 1              # 与 start.sh 一致：隔 1 秒补写，兜住较晚的屏幕重绘
			show_ip
		else
			show_ip              # 启动即有网 / IP 变化：保持原有单次刷新，逻辑不变
		fi
		last_ip="$ip"
	fi

	# 首轮与基线几乎无时间间隔，只重置基线不累计空闲，避免计时偏快一个采样周期
	[ "$boot" = "1" ] && { quiet=0; prev=$(sample); continue; }

	# —— 空闲(无传输)计时：仅在「已联网」时才计数 ——
	# 「从不」= 关闭此功能（等价旧版「取消闲置退出」）：清空计时、刷新基线、继续待命，不判定不退出
	if [ "$SECS" -le 0 ] 2>/dev/null; then
		quiet=0; prev=$(sample); continue
	fi
	cur=$(sample)
	if changed "$prev" "$cur"; then quiet=0; else quiet=$(( quiet + STEP )); fi
	prev=$cur
	if [ "$quiet" -ge "$SECS" ]; then
		status "No traffic $(( SECS / 60 ))min, closing..."; sleep 1
		sh ./stop.sh
		exit 0
	fi
done
