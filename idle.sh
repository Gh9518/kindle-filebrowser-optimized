#!/bin/sh
# 闲置退出守护：连续 1 分钟 80 端口无任何传输，则执行与「关闭」相同的逻辑
#
# 判定依据：iptables 中 --dport 80 规则的累计计数（只统计访问本服务的流量，
#           Kindle 后台联网不会计入，实测空闲期计数恒定不变、一次页面请求即明显增长）；
#           若该规则不可用，退化为统计非 lo 网卡字节数，并加阈值过滤后台噪声。
# 与「定时退出」(autoclose.sh) 完全独立，两者互不影响，谁先到谁触发关闭。
# 菜单「取消闲置退出」会写 IDLE=off，本脚本据此暂停判定（不退出、继续待命）；
# 恢复为 on 时无需重启脚本，即时生效。
cd "$(dirname "$0")" || exit 1
. ./lib.sh

IDLE_SECS=${IDLE_SECS:-60}   # 连续无传输多少秒后退出（默认 1 分钟）
STEP=${IDLE_STEP:-10}        # 采样间隔（秒）
DEV_MIN=4096                 # fallback 模式：采样间隔内字节增量超过此值才算「有传输」

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

prev=$(sample)
quiet=0
while :; do
	sleep "$STEP"
	listening || exit 0
	# 已被「取消闲置退出」关闭：清空计时、刷新基线，继续待命（不判定、不退出）
	if [ -f IDLE ] && [ "$(cat IDLE 2>/dev/null)" = "off" ]; then
		quiet=0; prev=$(sample); continue
	fi
	cur=$(sample)
	if changed "$prev" "$cur"; then quiet=0; else quiet=$(( quiet + STEP )); fi
	prev=$cur
	if [ "$quiet" -ge "$IDLE_SECS" ]; then
		status "Idle 1min, closing..."; sleep 1
		sh ./stop.sh
		exit 0
	fi
done
