#!/bin/sh
# 关闭 / 自动退出的唯一出口：结束 filebrowser 与自动退出守护，按启动时的网络状态还原飞行模式，再返回主页
# 手动「关闭」与「空闲自动退出」(idle.sh 触发) 都调用本脚本，
# 因此两者共享同一套「按启动时是否飞行模式还原网络」的状态机逻辑，不会各自为政。
cd "$(dirname "$0")" || exit 1
. ./lib.sh

# 结束 filebrowser
ps aux | grep [f]ilebrowser | awk '{print $2}' | xargs -i kill {} 2>/dev/null
killall filebrowser 2>/dev/null
# 结束自动退出守护（含旧版残留的 autoclose.sh），避免服务关闭后残留的守护再次触发
# 排除调用者的父进程：自动退出是 idle.sh 调用本脚本，不能把自己这棵调用链杀掉导致退出流程中断
CALLER=$PPID
for p in $(ps aux 2>/dev/null | grep -E '[i]dle.sh|[a]utoclose.sh' | awk '{print $2}'); do
	[ "$p" = "$CALLER" ] && continue
	kill "$p" 2>/dev/null
done
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
