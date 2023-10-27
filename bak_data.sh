#!/bin/bash

echo "#############$(date "+%Y-%m-%d %H:%M:%S")#############"

# 重复执行某个命令，直至成功，间隔30秒
repeat() { while :; do $@ && return; sleep 30; done }

# 获取脚本文件所在目录的绝对路径
script_path=$(cd $(dirname ${0}); pwd) 

# 备份到github仓库
cd ${script_path}
/usr/local/git/bin/git add .
/usr/local/git/bin/git commit -m "backup files"
repeat /usr/local/git/bin/git push origin main
