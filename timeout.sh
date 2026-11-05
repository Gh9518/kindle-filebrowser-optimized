#!/bin/sh
# 设置自动退出时间（秒 $1，标签 $2）并刷新菜单
echo "$1" > AUTOCLOSE
. ./lib.sh
# 先重建 menu.json：确保 KUAL 触发 refresh 重新读取时拿到的就是新值，
# 避免“点到第二次才生效”的竞态（若菜单在 sleep 之后才重建，KUAL 会先读到旧菜单）。
sh ./genmenu.sh
# eips 屏显无中文字形，状态提示统一用英文；放在菜单重建之后，不阻塞刷新
status "Auto-exit: $(adisp_en "$1")"; sleep 2; status ""
