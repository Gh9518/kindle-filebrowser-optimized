#!/bin/sh
# 屏幕显示本机 IP（位置见 lib.sh 中 IP_ROW / IP_COL，改那里即全局生效）
. ./lib.sh
show_ip
sh ./genmenu.sh >/dev/null 2>&1
