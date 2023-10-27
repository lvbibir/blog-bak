# 关于仓库
用于备份我的私有云环境中的各项服务配置文件及关键数据

# 备份策略
每天备份，采用linux的crontab配合shell脚本实现

# crontab

```
[root@lvbibir ~]# crontab -l
0 23 * * * /usr/bin/sh /root/blog/bak_data.sh >> /var/log/baklog 2>&1
```
