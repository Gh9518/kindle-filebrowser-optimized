#!/bin/sh
# 公共函数库：各脚本用 `. ./lib.sh` 引入，避免重复代码

# 屏幕状态行所在列（更新/退出等提示，默认第 3 行）
COL=1
[ -f COL.txt ] && COL=$((`cat COL.txt`))

# 取本机 IP：依次尝试常见无线接口，无连接返回“未连接”
# 兼容不同 Kindle 型号（wlan0 / eth0 / mlan0 等），避免接口名不同导致取不到 IP
ip_addr() {
	for ifc in wlan0 eth0 mlan0 tiwlan0; do
		ip=$(ifconfig "$ifc" 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p' | head -1)
		[ -n "$ip" ] && { echo "$ip"; return; }
	done
	echo "未连接"
}

# 屏幕状态行输出（左对齐覆盖，防拖影）
status() {
	eips $COL 3 "$(printf '%-42s' "$1")"
}

# 在屏幕显示本机 IP（位置可改下方 IP_ROW / IP_COL；改这里即全局生效）
IP_ROW=12  # 第几行显示（越大越靠下）
IP_COL=3   # 第几列显示（越大越靠右）
show_ip() {
	eips $IP_ROW $IP_COL "IP: $(ip_addr)"
}

# 完全脱离终端后台运行（避免 KUAL 关闭其管道后被 SIGPIPE 拖垮崩溃）
# 用法：detach <命令> [参数...]，并在调用处自行重定向 I/O
detach() {
	if command -v setsid >/dev/null 2>&1; then
		setsid "$@"
	else
		nohup "$@"
	fi
}

# 读取当前无线状态：1=无线开(非飞行模式) 0=飞行模式(无线关) 读不到默认 1
wireless_state() {
	st=$(lipc-get-prop com.lab126.cmd wirelessEnable 2>/dev/null)
	[ "$st" = "0" ] && echo 0 || echo 1
}

# 界面语言：默认中文；仅当 LANG 文件显式写 en 时才切换为英文
# 说明：不依据 Kindle 系统语言自动判断，确保任何系统语言下打开都是中文（真正的“默认中文”）；
#       非中文用户点菜单最后的语言项即可切换（等效于写 LANG 文件）。
sys_lang() {
	[ -f LANG ] && { read -r o < LANG; case "$o" in
		*[Ee][Nn]*) echo en; return ;;
		*) echo zh; return ;;
	esac; }
	echo zh
}

# 秒数 → 英文紧凑文案（eips 屏显无中文字形，状态提示统一用英文）
# 空闲退出档位 从不/01/03/05 分；兜底按分钟换算，兼容旧 AUTOCLOSE 值（如 900→15min）
adisp_en() {
	case "$1" in
		0)    printf 'Never' ;;
		60)   printf '01min' ;;
		180)  printf '03min' ;;
		300)  printf '05min' ;;
		*)    printf '%02dmin' "$(( $1 / 60 ))" ;;
	esac
}
