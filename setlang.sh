#!/bin/sh
# 设置界面语言并刷新菜单：./setlang.sh zh | en
# 写入 LANG 文件后重建 menu.json，KUAL 通过 refresh:true 重新加载即生效
[ -n "$1" ] && printf '%s\n' "$1" > LANG
sh ./genmenu.sh
