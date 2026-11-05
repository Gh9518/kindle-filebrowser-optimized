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

# 系统语言判断：默认显示中文菜单；LANG 文件可手动强制为英文
# 读取顺序：1) 插件目录 LANG 文件可手动强制（写 en→英文 / zh→中文）；
#           2) 否则按 Kindle UI 语言自动（含 zh 即中文，明确为 en 才英文）；
#           3) 未识别系统语言时默认中文
sys_lang() {
	[ -f LANG ] && { read -r o < LANG; case "$o" in
		*[Zz][Hh]*) echo zh; return ;;
		*[Ee][Nn]*) echo en; return ;;
	esac; }
	l=$(lipc-get-prop com.lab126.winmgr lang 2>/dev/null)
	case "$l" in
		*[Zz][Hh]*) echo zh ;;
		*[Ee][Nn]*) echo en ;;
		*) echo zh ;;
	esac
}

# 秒数 → 英文紧凑文案（eips 屏显无中文字形，状态提示统一用英文）
adisp_en() {
	case "$1" in
		0)    printf 'Never' ;;
		300)  printf '05min' ;;
		900)  printf '15min' ;;
		1800) printf '30min' ;;
		3600) printf '60min' ;;
		*)    printf '%ssec' "$1" ;;
	esac
}
