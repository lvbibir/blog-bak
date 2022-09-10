#!/bin/bash

# 获取脚本文件所在目录的绝对路径
script_path=$(cd $(dirname ${0}); pwd) 

# 删除wordpress备份的文件
/usr/bin/rm -f ${script_path}/backup/wordpress/*

# 获取UpdraftPlus备份的wordpress数据
if [ "$(date "+%u")" == "1" ];then
/usr/bin/cp -p ${script_path}/data/wordpress/wp-content/updraft/backup_$(date "+%Y-%m-%d")* ${script_path}/bak/wordpress/
fi

# 备份到github仓库
git add --all
git commit -m "backup files"
git push origin main
