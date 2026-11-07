#!/bin/sh
# 设置「连续无传输 N 秒后自动退出」（秒 $1，标签 $2）并刷新菜单
# AUTOCLOSE 是唯一的自动退出设置：0=从不(关闭此功能)、60/180/300=1/3/5 分无传输即退出。
# 守护 idle.sh 每轮重读本文件，故这里只写值即可即时生效（无需重启守护）。
echo "$1" > AUTOCLOSE
. ./lib.sh
# 先重建 menu.json：确保 KUAL 触发 refresh 重新读取时拿到的就是新值，
# 避免“点到第二次才生效”的竞态（若菜单在 sleep 之后才重建，KUAL 会先读到旧菜单）。
sh ./genmenu.sh
# eips 屏显无中文字形，状态提示统一用英文；放在菜单重建之后，不阻塞刷新
status "Auto-exit: $(adisp_en "$1")"; sleep 2; status ""
