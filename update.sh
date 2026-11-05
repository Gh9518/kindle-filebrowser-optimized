#!/bin/sh
# 核心程序更新：check=校验可用更新；do=下载安装
. ./lib.sh

REPO="https://github.com/filebrowser/filebrowser"
ART="linux-armv7-filebrowser.tar.gz"
LOCAL=$(cat BINFILE_VERSION 2>/dev/null)
[ -z "$LOCAL" ] && LOCAL="未知"

latest_tag() {
	curl -s -m 20 -H 'Accept: application/json' "$REPO/releases/latest" 2>/dev/null \
		| sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/'
}

# $1 比 $2 新则返回 0（按 主.次.修订 数值比较）
vergt() {
	a=$(echo "$1" | sed 's/^v//'); b=$(echo "$2" | sed 's/^v//')
	set -- $(echo "$a" | awk -F. '{print $1+0,$2+0,$3+0}') \
	       $(echo "$b" | awk -F. '{print $1+0,$2+0,$3+0}')
	[ "$1" -gt "$4" ] && return 0; [ "$1" -lt "$4" ] && return 1
	[ "$2" -gt "$5" ] && return 0; [ "$2" -lt "$5" ] && return 1
	[ "$3" -gt "$6" ] && return 0; [ "$3" -lt "$6" ] && return 1
	return 1
}

do_update() {
	REMOTE=$(latest_tag)
	[ -z "$REMOTE" ] || [ "$REMOTE" = "null" ] && { status "Connect FAILED"; sleep 3; return 1; }
	status "Connected: $REMOTE"; sleep 1
	URL="$REPO/releases/download/$REMOTE/$ART"
	if [ ! -e "$ART" ]; then
		TOTAL=$(curl -sIL --max-time 15 "$URL" 2>/dev/null | grep -i content-length | tail -1 | tr -d '\r' | awk '{print $2}')
		status "Downloading..."; wget -T 60 -t 3 -O "$ART" "$URL" &
		WPID=$!
		while kill -0 $WPID 2>/dev/null; do
			CUR=$(wc -c < "$ART" 2>/dev/null || echo 0)
			if [ -n "$TOTAL" ] && [ "$TOTAL" -gt 0 ] 2>/dev/null; then
				status "Download $((CUR*100/TOTAL))% ($((CUR/1024))/$((TOTAL/1024))K)"
			else
				status "Download $((CUR/1024))K"
			fi
			sleep 2
		done
		wait $WPID
		[ $? -ne 0 ] && { status "Download FAILED"; rm -f "$ART"; sleep 3; return 1; }
	fi
	if tar -xf "$ART" && chmod +x filebrowser && echo "$REMOTE" > BINFILE_VERSION; then
		rm -f "$ART"; status "Update done: $REMOTE"
	else
		rm -f "$ART"; status "Broken file"; sleep 3; return 1
	fi
	sleep 2
}

case "$1" in
	check)
		status "检查更新中..."
		REMOTE=$(latest_tag)
		if [ -z "$REMOTE" ] || [ "$REMOTE" = "null" ]; then
			echo "error|网络失败" > UPDATE_INFO; status "检查失败: 网络错误"
		elif [ "$LOCAL" = "未知" ] || vergt "$REMOTE" "$LOCAL"; then
			echo "available|$REMOTE|$LOCAL" > UPDATE_INFO; status "发现新版本: $REMOTE"
		else
			echo "latest|$LOCAL" > UPDATE_INFO; status "已是最新: $LOCAL"
		fi
		sleep 2; sh ./genmenu.sh
		;;
	do)
		do_update; sleep 1; rm -f UPDATE_INFO; sh ./genmenu.sh
		;;
esac
