#!/bin/sh
# 关闭：结束 filebrowser，并按启动时的网络状态还原飞行模式，再返回主页
. ./lib.sh

# 结束 filebrowser
ps aux | grep [f]ilebrowser | awk '{print $2}' | xargs -i kill {} 2>/dev/null
killall filebrowser 2>/dev/null
lipc-set-prop -i com.lab126.powerd preventScreenSaver 0 2>/dev/null

# 还原飞行模式：仅当“启动时处于飞行模式”，才在退出时重新开启；
# 若启动时并非飞行模式，则退出时不动 WiFi（保持原样）
INIT=1
[ -f WIFI_STATE ] && INIT=$(cat WIFI_STATE)
if [ "$INIT" = "0" ]; then
	lipc-set-prop com.lab126.cmd wirelessEnable 0 2>/dev/null
	sleep 1
	lipc-set-prop com.lab126.wifid enable 0 2>/dev/null
	st=$(lipc-get-prop com.lab126.cmd wirelessEnable 2>/dev/null)
	[ "$st" = "0" ] && status "飞行模式: 已开启" || status "飞行模式: 失败($st)"
	sleep 2; status ""
fi

# 返回主页
lipc-send-event com.lab126.hal powerButtonPressed
sleep 5
