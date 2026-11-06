#!/bin/sh
# 生成 KUAL 菜单 menu.json
# 语言：默认中文；可手动切换英文（菜单底部“英语/中文”项 / LANG 文件）
# 执行 `genmenu.sh --choose` 时，显示双语“选择语言”菜单（菜单底部语言项点开即进入）
# 要点：不带 exitmenu:false 的项，KUAL 执行完动作后默认返回 Kindle 桌面；
#       仅“需留在菜单继续操作”的项（自动退出/更新子项、本机IP 显示）才写 exitmenu:false
. ./lib.sh

# 插件版本（用于菜单标题展示；改 VERSION 文件即可）
VER=$(cat VERSION 2>/dev/null); [ -z "$VER" ] && VER="2.0"

# 运行模式：--choose 才进入语言选择；默认直接以中文呈现（无 LANG 文件时 sys_lang 也默认中文）
if [ "$1" = "--choose" ]; then
	MODE="choose"
else
	MODE="normal"
fi

# 系统语言（zh / en）
L=$(sys_lang)

AUTOCLOSE=300; [ -f AUTOCLOSE ] && AUTOCLOSE=$(cat AUTOCLOSE)
UPDATE_INFO=""; [ -f UPDATE_INFO ] && UPDATE_INFO=$(cat UPDATE_INFO)
IP=$(ip_addr)

# ---- 多语言文案 ----
if [ "$L" = "zh" ]; then
	TITLE="网页文件管理器 2";  START_N="启动";   CLOSE_N="关闭"
	AUTOLBL="自动退出";      IPPRE="本机IP";  OFFLINE="未连接"
	FLIGHT_T="当前为飞行模式，WiFi 已关闭"; FLIGHT_C="打开网络并继续"; FLIGHT_X="暂不启动"
	UPD_T="更新核心程序"
	UPD_FOUND(){ echo "发现新版本: $1（当前 $2）"; }
	UPD_CONFIRM="确认更新"; UPD_LATER="暂不更新"
	UPD_LATEST(){ echo "已是最新: $1"; }
	UPD_BACK="返回"
	UPD_FAIL(){ echo "检查失败: $1"; }
	UPD_RETRY="重试"
else
	TITLE="Web File Browser 2"; START_N="Start";  CLOSE_N="Close"
	AUTOLBL="Auto-exit";      IPPRE="Local IP"; OFFLINE="Offline"
	FLIGHT_T="Airplane mode on, WiFi off"; FLIGHT_C="Turn on network & continue"; FLIGHT_X="Don't start"
	UPD_T="Update core"
	UPD_FOUND(){ echo "New version: $1 (current $2)"; }
	UPD_CONFIRM="Confirm update"; UPD_LATER="Not now"
	UPD_LATEST(){ echo "Up to date: $1"; }
	UPD_BACK="Back"
	UPD_FAIL(){ echo "Check failed: $1"; }
	UPD_RETRY="Retry"
fi

# IP 标签
[ "$IP" = "未连接" ] && LABEL="$IPPRE: $OFFLINE" || LABEL="$IPPRE: $IP"

# 语言切换项（菜单最后一项）：中文菜单显示英文名称 English，英文菜单显示中文名 中文
# 即始终显示“将要切换到的目标语言”本身的名字，便于使用者辨识与修改
LANGN="English"; [ "$L" = "en" ] && LANGN="中文"

tick() { [ "$1" = "$2" ] && printf '✓ ' || printf '  '; }

# 秒数 → 紧凑显示文案（跟随系统语言）
# 菜单选项见下方 T_VALS（01/03/05/10 分）；保留 0 及按分钟换算的兜底，兼容旧设备残留的 AUTOCLOSE 值
tlabel() {
	case "$1" in
		0)    [ "$L" = "zh" ] && printf '从不' || printf 'Never' ;;
		60)   [ "$L" = "zh" ] && printf '01分' || printf '01min' ;;
		180)  [ "$L" = "zh" ] && printf '03分' || printf '03min' ;;
		300)  [ "$L" = "zh" ] && printf '05分' || printf '05min' ;;
		600)  [ "$L" = "zh" ] && printf '10分' || printf '10min' ;;
		*)    [ "$L" = "zh" ] && printf '%02d分' "$(( $1 / 60 ))" || printf '%02dmin' "$(( $1 / 60 ))" ;;
	esac
}
ADISP=$(tlabel "$AUTOCLOSE")

# 启动项：飞行模式下先提示“是否打开网络”，否则直接启动
# 注意：启动动作不带 exitmenu:false，执行完由 KUAL 默认返回桌面
if [ "$(wireless_state)" = "0" ]; then
	START="{ \"name\": \"$START_N\", \"priority\": 1, \"refresh\": true, \"items\": [
		{ \"name\": \"$FLIGHT_T\", \"priority\": 1, \"action\": \"echo\", \"param\": \"\", \"exitmenu\": false },
		{ \"name\": \"$FLIGHT_C\", \"priority\": 2, \"action\": \"./start.sh\", \"param\": \"\" },
		{ \"name\": \"$FLIGHT_X\", \"priority\": 3, \"action\": \"sh ./genmenu.sh\", \"param\": \"\", \"exitmenu\": false, \"refresh\": true }
	] }"
else
	START="{ \"name\": \"$START_N\", \"priority\": 1, \"action\": \"./start.sh\", \"param\": \"\" }"
fi

# 自动退出时间选项（值列表，秒）：01分 / 03分 / 05分 / 10分；当前项加 ✓（默认 05分）
# 短档位覆盖多数使用场景，避免长时间挂机耗电；子项 exitmenu:false + refresh:true 选中后即时刷新
T_VALS="60 180 300 600"
TO=""
for v in $T_VALS; do
	l=$(tlabel "$v")
	TO="$TO
				{ \"name\": \"$(tick "$v" "$AUTOCLOSE")$l\", \"priority\": 1, \"action\": \"./timeout.sh $v $l\", \"param\": \"\", \"exitmenu\": false, \"refresh\": true },"
done
TO=$(printf '%s' "$TO" | sed '$ s/,$//')

# “更新核心程序”菜单项（依校验状态）
# 子项 exitmenu:false + refresh:true：选中后留在菜单并即时刷新
if [ -z "$UPDATE_INFO" ]; then
	UPD="{ \"name\": \"$UPD_T\", \"priority\": 5, \"action\": \"./update.sh check\", \"param\": \"\", \"exitmenu\": false, \"refresh\": true }"
else
	s=$(printf '%s' "$UPDATE_INFO" | cut -d'|' -f1)
	a1=$(printf '%s' "$UPDATE_INFO" | cut -d'|' -f2)
	a2=$(printf '%s' "$UPDATE_INFO" | cut -d'|' -f3)
	if [ "$s" = "available" ]; then
		f=$(UPD_FOUND "$a1" "$a2")
		UPD="{ \"name\": \"$UPD_T\", \"priority\": 5, \"refresh\": true, \"items\": [
			{ \"name\": \"$f\", \"priority\": 1, \"action\": \"echo\", \"param\": \"\", \"exitmenu\": false },
			{ \"name\": \"$UPD_CONFIRM\", \"priority\": 2, \"action\": \"./update.sh do\", \"param\": \"\", \"exitmenu\": false, \"refresh\": true },
			{ \"name\": \"$UPD_LATER\", \"priority\": 3, \"action\": \"rm -f UPDATE_INFO; sh ./genmenu.sh\", \"param\": \"\", \"exitmenu\": false, \"refresh\": true }
		] }"
	elif [ "$s" = "latest" ]; then
		f=$(UPD_LATEST "$a1")
		UPD="{ \"name\": \"$UPD_T\", \"priority\": 5, \"refresh\": true, \"items\": [
			{ \"name\": \"$f\", \"priority\": 1, \"action\": \"echo\", \"param\": \"\", \"exitmenu\": false },
			{ \"name\": \"$UPD_BACK\", \"priority\": 2, \"action\": \"rm -f UPDATE_INFO; sh ./genmenu.sh\", \"param\": \"\", \"exitmenu\": false, \"refresh\": true }
		] }"
	else
		f=$(UPD_FAIL "$a1")
		UPD="{ \"name\": \"$UPD_T\", \"priority\": 5, \"refresh\": true, \"items\": [
			{ \"name\": \"$f\", \"priority\": 1, \"action\": \"echo\", \"param\": \"\", \"exitmenu\": false },
			{ \"name\": \"$UPD_RETRY\", \"priority\": 2, \"action\": \"./update.sh check\", \"param\": \"\", \"exitmenu\": false, \"refresh\": true },
			{ \"name\": \"$UPD_BACK\", \"priority\": 3, \"action\": \"rm -f UPDATE_INFO; sh ./genmenu.sh\", \"param\": \"\", \"exitmenu\": false, \"refresh\": true }
		] }"
	fi
fi

# 首次运行 / 强制选择：显示双语“选择语言”菜单（无需预知系统语言即可选取）
if [ "$MODE" = "choose" ]; then
cat > menu.json.tmp <<JSON
{
	"items": [
		{
			"name": "选择语言 / Select language",
			"priority": -1,
			"items": [
				{ "name": "中文", "priority": 1, "action": "./setlang.sh zh", "param": "", "exitmenu": false, "refresh": true },
				{ "name": "English", "priority": 2, "action": "./setlang.sh en", "param": "", "exitmenu": false, "refresh": true }
			]
		}
	]
}
JSON
mv -f menu.json.tmp menu.json
exit 0
fi

# 外层标题：KUAL 启动器点进本程序后显示的内部菜单
cat > menu.json.tmp <<JSON
{
	"items": [
		{
			"name": "$TITLE",
			"priority": -1,
			"items": [
			$START
			,
			{ "name": "$CLOSE_N", "priority": 2, "action": "./stop.sh", "param": "" }
			,
			{ "name": "$AUTOLBL: $ADISP", "priority": 3, "items": [
$TO
			] }
			,
			$UPD
			,
			{ "name": "$LABEL", "priority": 6, "action": "echo", "param": "", "exitmenu": false }
			,
			{ "name": "$LANGN", "priority": 7, "action": "sh ./genmenu.sh --choose", "param": "", "exitmenu": false, "refresh": true }
		]
	}
]
}
JSON
mv -f menu.json.tmp menu.json
