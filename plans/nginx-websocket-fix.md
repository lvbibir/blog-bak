# Nginx WebSocket 代理配置修复方案

## 问题描述

mihomo webui 通过 nginx 反向代理后,HTTPS 功能正常,但 WebSocket 连接失败。

**错误信息:**
```
WebSocket connection to 'wss://www.lvbibir.cn/mihomo/traffic?token=123456' failed
WebSocket connection to 'wss://www.lvbibir.cn/mihomo/logs?token=123456&level=warning' failed
WebSocket connection to 'wss://www.lvbibir.cn/mihomo/connections?token=123456' failed
WebSocket connection to 'wss://www.lvbibir.cn/mihomo/memory?token=123456' failed
```

## 根本原因

当前的 nginx 配置缺少 WebSocket 协议升级所需的关键 HTTP 头信息:
- 缺少 `proxy_http_version 1.1;` - WebSocket 需要 HTTP/1.1
- 缺少 `proxy_set_header Upgrade $http_upgrade;` - 转发升级请求
- 缺少 `proxy_set_header Connection "upgrade";` - 转发连接升级头

## 技术背景

### WebSocket 握手流程

1. 客户端发送带有 `Upgrade: websocket` 和 `Connection: Upgrade` 头的 HTTP 请求
2. 服务器响应 101 状态码 (Switching Protocols),同意协议升级
3. 连接从 HTTP 切换到 WebSocket 协议,开始双向通信

### Nginx 代理 WebSocket 的要求

- 必须使用 HTTP/1.1 协议
- 必须正确转发 Upgrade 和 Connection 头
- 建议增加超时时间,因为 WebSocket 是长连接

## 解决方案

### 修改配置文件

文件路径: `conf/nginx-proxy/default.conf`

在 `location /mihomo/` 块中添加以下配置:

```nginx
location /mihomo/ {
    proxy_pass http://172.19.0.1:9090/;
    proxy_redirect off;
    
    # 基本代理头
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Real-Port $remote_port;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header HTTP_X_FORWARDED_FOR $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $host;
    proxy_set_header X-NginX-Proxy true;
    proxy_set_header Accept-Encoding "br";
    
    # WebSocket 支持 (新增)
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    
    # 超时设置 (新增,用于长连接)
    proxy_connect_timeout 60s;
    proxy_send_timeout 600s;
    proxy_read_timeout 600s;
}
```

### 配置项说明

| 配置项 | 作用 | 必需性 |
|--------|------|--------|
| `proxy_http_version 1.1` | 指定使用 HTTP/1.1 协议,WebSocket 必需 | 必需 |
| `proxy_set_header Upgrade $http_upgrade` | 转发客户端的 Upgrade 头到后端 | 必需 |
| `proxy_set_header Connection "upgrade"` | 设置 Connection 头为 upgrade | 必需 |
| `proxy_connect_timeout 60s` | 与后端建立连接的超时时间 | 推荐 |
| `proxy_send_timeout 600s` | 向后端发送数据的超时时间 | 推荐 |
| `proxy_read_timeout 600s` | 从后端读取数据的超时时间 | 推荐 |

## 实施步骤

### 1. 备份当前配置

```bash
cp conf/nginx-proxy/default.conf conf/nginx-proxy/default.conf.bak
```

### 2. 修改配置文件

编辑 `conf/nginx-proxy/default.conf`,在 `location /mihomo/` 块中添加上述 WebSocket 支持配置。

### 3. 验证配置语法

```bash
# 如果 nginx 在 docker 容器中
docker exec <nginx容器名> nginx -t

# 如果 nginx 直接安装在系统中
nginx -t
```

预期输出:
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 4. 重载 nginx 配置

```bash
# 如果 nginx 在 docker 容器中
docker exec <nginx容器名> nginx -s reload

# 如果 nginx 直接安装在系统中
systemctl reload nginx
# 或
nginx -s reload
```

### 5. 测试 WebSocket 连接

#### 方法一: 浏览器开发者工具

1. 打开浏览器,访问 `https://www.lvbibir.cn/mihomo/`
2. 按 F12 打开开发者工具
3. 切换到 Network 标签
4. 筛选 WS (WebSocket) 类型的连接
5. 检查 WebSocket 连接状态:
   - 状态码应该是 `101 Switching Protocols`
   - Status 应该显示为绿色的 `101`
   - 不应该有连接失败的错误

#### 方法二: 查看 nginx 日志

```bash
# 查看 nginx 访问日志
docker logs <nginx容器名> | grep mihomo

# 查看 nginx 错误日志
docker logs <nginx容器名> | grep -i error
```

#### 方法三: 使用 wscat 测试工具

```bash
# 安装 wscat
npm install -g wscat

# 测试 WebSocket 连接
wscat -c "wss://www.lvbibir.cn/mihomo/traffic?token=123456"
```

## 故障排查

### 问题 1: 配置语法错误

**症状:** `nginx -t` 报错

**解决:** 检查配置文件语法,确保每行末尾有分号,大括号匹配

### 问题 2: WebSocket 连接仍然失败

**排查步骤:**

1. 检查后端服务是否正常运行:
   ```bash
   curl http://172.19.0.1:9090/
   ```

2. 检查 nginx 错误日志:
   ```bash
   docker logs <nginx容器名> | tail -50
   ```

3. 确认 WebSocket 路径是否正确:
   - 确保后端服务支持 `/traffic`, `/logs`, `/connections`, `/memory` 等路径

4. 检查防火墙规则:
   ```bash
   iptables -L -n | grep 9090
   ```

### 问题 3: 连接超时

**症状:** WebSocket 连接建立后很快断开

**解决:** 增加超时时间:
```nginx
proxy_connect_timeout 120s;
proxy_send_timeout 1200s;
proxy_read_timeout 1200s;
```

### 问题 4: SSL/TLS 握手失败

**排查:**
1. 检查 SSL 证书是否有效:
   ```bash
   openssl s_client -connect www.lvbibir.cn:443 -servername www.lvbibir.cn
   ```

2. 确认证书文件路径正确:
   - `ssl_certificate /etc/nginx/ssl/lvbibir.cn.pem;`
   - `ssl_certificate_key /etc/nginx/ssl/lvbibir.cn.key;`

## 其他建议

### 1. 为其他服务添加 WebSocket 支持

如果 `/twikoo/`, `/busuanzi/` 等其他服务也使用 WebSocket,建议同样添加这些配置:

```nginx
location /twikoo/ {
    proxy_pass http://172.19.0.4:8080/;
    # ... 其他配置 ...
    
    # WebSocket 支持
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

### 2. 创建 map 指令优化配置

在 `http` 块中添加:

```nginx
http {
    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }
    
    server {
        # ...
        location /mihomo/ {
            # ...
            proxy_set_header Connection $connection_upgrade;
        }
    }
}
```

这样可以:
- 当请求包含 Upgrade 头时,设置 Connection 为 upgrade
- 当请求不包含 Upgrade 头时,设置 Connection 为 close
- 同时支持普通 HTTP 和 WebSocket 请求

### 3. 性能优化

```nginx
# 禁用缓冲以减少延迟
proxy_buffering off;

# 增加缓冲区大小
proxy_buffer_size 4k;
proxy_buffers 8 4k;
```

## 验证清单

- [ ] 配置文件已备份
- [ ] WebSocket 相关配置已添加
- [ ] `nginx -t` 验证通过
- [ ] nginx 已重载配置
- [ ] 浏览器 F12 中 WebSocket 连接状态为 101
- [ ] mihomo webui 功能正常,实时数据更新正常
- [ ] 没有 WebSocket 连接错误

## 预期结果

修复后,在浏览器开发者工具的 Network 标签中应该看到:

```
Name: traffic?token=123456
Status: 101 Switching Protocols
Type: websocket
Size: (pending)
Time: (pending)
```

WebSocket 连接应该保持打开状态,mihomo webui 应该能够实时显示流量、连接、日志等信息。

## 参考资料

- [Nginx WebSocket 代理官方文档](http://nginx.org/en/docs/http/websocket.html)
- [HTTP 协议升级机制 (RFC 6455)](https://datatracker.ietf.org/doc/html/rfc6455)
- [Nginx 反向代理配置](http://nginx.org/en/docs/http/ngx_http_proxy_module.html)
