#!/bin/bash

# 重复执行某个命令，直至成功，间隔30秒
repeat() { while :; do $@ && return; sleep 30; done }

# 获取脚本文件所在目录的绝对路径
script_path=$(cd $(dirname ${0}); pwd) 

# 获取UpdraftPlus备份的wordpress数据（仅周一）
if [ "$(date "+%u")" == "1" ];then
/usr/bin/rm -f ${script_path}/backup/wordpress/*
/usr/bin/cp -p ${script_path}/data/wordpress/wp-content/updraft/backup_$(date "+%Y-%m-%d")* ${script_path}/backup/wordpress/
fi

# 备份到github仓库
cd ${script_path}
/usr/local/git/bin/git add .
/usr/local/git/bin/git commit -m "backup files"
repeat git push origin main
