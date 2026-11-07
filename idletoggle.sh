#!/bin/sh
# 「取消闲置退出 / 恢复闲置退出」开关：写 IDLE 文件（off / on），即时生效
# 只影响「1 分钟不传输即退出」的闲置检测；定时退出(从不/03/05/10分)完全不受影响，
# 即「取消闲置退出」后其它自动退出选项仍然照常应用。
cd "$(dirname "$0")" || exit 1
. ./lib.sh

if [ -f IDLE ] && [ "$(cat IDLE 2>/dev/null)" = "off" ]; then
	echo on > IDLE
	msg="Idle-exit: ON"
else
	echo off > IDLE
	msg="Idle-exit: OFF"
fi

# 先重建菜单，确保 KUAL 刷新时立即显示新的开关标签（避免点两次才生效的竞态）
sh ./genmenu.sh
status "$msg"; sleep 2; status ""
