# OpenResty 生产级双节点高可用部署指南

> **适用版本**：OpenResty 1.25.3.x（LTS）
> **更新时间**：2026-03
> **部署模式**：双节点 Active-Active + Keepalived VIP + lsyncd 配置实时同步

---

## 目录

1. [简介与架构](#1-简介与架构)
2. [环境规划](#2-环境规划)
3. [安装 OpenResty（两台节点）](#3-安装-openresty两台节点)
4. [生产级 nginx.conf 配置](#4-生产级-nginxconf-配置)
5. [Keepalived 高可用 VIP](#5-keepalived-高可用-vip)
6. [配置实时同步方案（lsyncd）](#6-配置实时同步方案lsyncd)
7. [Lua 扩展示例](#7-lua-扩展示例)
8. [性能调优](#8-性能调优)
9. [监控接入](#9-监控接入)
10. [日常运维](#10-日常运维)
11. [常见问题排查](#11-常见问题排查)

---

## 1. 简介与架构

### 1.1 OpenResty 简介

OpenResty 是基于 **Nginx + LuaJIT** 的可编程 Web 平台，将 Nginx 的高性能与 Lua 脚本的灵活性结合：

- 🚀 **高性能**：继承 Nginx 事件驱动模型，单机可处理数十万并发
- 🔧 **可编程**：通过 `*_by_lua_block` 指令在 Nginx 生命周期任意阶段执行 Lua 代码
- 📦 **丰富生态**：lua-resty-redis、lua-resty-mysql、lua-resty-jwt 等开箱即用
- 🌐 **网关能力**：限流、鉴权、灰度发布、动态路由均可原生实现

### 1.2 生产架构图

```
                    ┌─────────────────────────────────────┐
                    │         客户端 / 上游请求              │
                    └──────────────────┬──────────────────┘
                                       │
                           VIP: 192.168.10.100:80/443
                      (Keepalived 虚拟 IP，自动漂移)
                                       │
               ┌───────────────────────┴──────────────────────┐
               │                                              │
    ┌──────────▼──────────┐                    ┌──────────────▼──────────┐
    │   openresty-node-01  │  ←── lsyncd ───→  │   openresty-node-02    │
    │   192.168.10.11      │   配置实时同步       │   192.168.10.12        │
    │   (Keepalived MASTER)│                    │   (Keepalived BACKUP)  │
    └──────────┬──────────┘                    └──────────────┬──────────┘
               │                                              │
               └──────────────────┬───────────────────────────┘
                                  │
                    ┌─────────────┼──────────────┐
                    │             │              │
           ┌────────▼──┐  ┌───────▼──┐  ┌───────▼──┐
           │  Backend-A │  │Backend-B │  │Backend-C │
           │  (上游服务) │  │(上游服务) │  │(上游服务) │
           └────────────┘  └──────────┘  └──────────┘
```

### 1.3 高可用方案选型

| 方案 | 原理 | 推荐场景 |
|------|------|---------|
| **Keepalived VIP**（本文） | VRRP 协议漂移虚拟 IP，一主一备 | 两节点，客户端通过 VIP 接入 |
| 上游 LB（如 LVS/HAProxy） | 将 OpenResty 作为后端池 | 三节点以上，水平扩展 |
| DNS 轮询 | 多 A 记录轮询 | 无状态场景，故障转移慢 |

### 1.4 配置同步方案选型

> **推荐：lsyncd**（本文采用），而非裸 `inotifywait + rsync` 脚本

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| **lsyncd**（推荐） | 内置 inotify + rsync，事件批处理，开箱即用，支持回调 reload | 需要安装 | ⭐⭐⭐⭐⭐ |
| inotifywait + rsync 脚本 | 原理透明，定制灵活 | 需自己处理事件风暴、错误重试 | ⭐⭐⭐ |
| Ansible + cron | 定期推送，简单 | 不实时，延迟高 | ⭐⭐ |
| Git Pull Hook | 版本化管理，回滚方便 | 需搭建 Git 服务 | ⭐⭐⭐⭐ |

---

## 2. 环境规划

### 2.1 节点信息

| 角色 | 主机名 | IP | 系统 | 规格 |
|------|--------|----|------|------|
| OpenResty 主节点 | `openresty-01` | `192.168.10.11` | Rocky Linux 9 / Ubuntu 24.04 | 4C8G / 100G SSD |
| OpenResty 备节点 | `openresty-02` | `192.168.10.12` | Rocky Linux 9 / Ubuntu 24.04 | 4C8G / 100G SSD |
| 虚拟 IP（VIP） | — | `192.168.10.100` | — | Keepalived 管理 |

### 2.2 端口规划

| 端口 | 协议 | 用途 |
|------|------|------|
| 80 | TCP | HTTP 入口 |
| 443 | TCP | HTTPS 入口 |
| 8080 | TCP | 健康检查 / 状态接口 |
| 112 | UDP | Keepalived VRRP 协议 |

### 2.3 目录规划

```
/etc/openresty/
├── nginx.conf              # 主配置文件
├── conf.d/                 # 虚拟主机配置（由 lsyncd 同步）
│   ├── default.conf
│   └── api-proxy.conf
├── ssl/                    # TLS 证书（由 lsyncd 同步）
│   ├── server.crt
│   └── server.key
└── lua/                    # Lua 脚本（由 lsyncd 同步）
    ├── auth.lua
    └── ratelimit.lua

/var/log/openresty/         # 日志目录（不同步，各节点独立）
/var/run/openresty/         # PID 等运行时文件
```

---

## 3. 安装 OpenResty（两台节点）

> 以下步骤在 **两台节点** 上均执行。

### 3.1 添加官方仓库

```bash
# ── Rocky Linux 9 ──────────────────────────────────────────────
# 添加 OpenResty 官方 YUM 仓库
curl -fsSL https://openresty.org/package/centos/openresty.repo \
    -o /etc/yum.repos.d/openresty.repo

# 或使用手动方式
cat > /etc/yum.repos.d/openresty.repo << 'EOF'
[openresty]
name=Official OpenResty Open Source Repository for CentOS
baseurl=https://openresty.org/package/centos/$releasever/$basearch
skip_if_unavailable=False
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://openresty.org/package/pubkey.gpg
enabled=1
EOF

# ── Ubuntu 24.04 ───────────────────────────────────────────────
# 安装必要依赖
apt-get update
apt-get install -y lsb-release curl gnupg2 ca-certificates

# 导入 GPG 公钥
curl -fsSL https://openresty.org/package/pubkey.gpg \
    | gpg --dearmor -o /usr/share/keyrings/openresty.gpg

# 添加 OpenResty 官方 APT 仓库
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openresty.gpg] \
https://openresty.org/package/ubuntu $(lsb_release -sc) main" \
    | tee /etc/apt/sources.list.d/openresty.list

apt-get update
```

### 3.2 安装 OpenResty 及常用模块

```bash
# ── Rocky Linux 9 ──────────────────────────────────────────────
# 安装 OpenResty 主程序及工具包
dnf install -y openresty openresty-opm openresty-resty

# ── Ubuntu 24.04 ───────────────────────────────────────────────
# 安装 OpenResty 主程序及工具包
apt-get install -y openresty
# opm 工具通过以下方式获取（两系统相同）
opm get ledgetech/lua-resty-http      # HTTP 客户端
opm get bungle/lua-resty-template     # 模板渲染
opm get pintsized/lua-resty-redis     # Redis 客户端（备用）
```

```bash
# ── 以下命令两个系统相同 ────────────────────────────────────────
# 通过 opm 安装常用 Lua 库
opm get ledgetech/lua-resty-http
opm get bungle/lua-resty-template
opm get pintsized/lua-resty-redis

# 验证安装
openresty -v
# 预期输出：openresty/1.25.3.x

# 查看编译参数（确认包含的模块）
openresty -V 2>&1 | grep -E "lua|ssl|gzip"
```

### 3.3 目录权限与系统服务

```bash
# 创建必要目录
mkdir -p /etc/openresty/conf.d
mkdir -p /etc/openresty/ssl
mkdir -p /etc/openresty/lua
mkdir -p /var/log/openresty
mkdir -p /var/run/openresty

# 设置权限
chown -R nobody:nobody /var/log/openresty
chmod 750 /etc/openresty/ssl

# 启用并启动 OpenResty
systemctl enable openresty --now

# 验证服务状态
systemctl status openresty
curl -I http://localhost  # 应返回 200 OK
```

### 3.4 安装配置同步依赖（两台节点）

```bash
# ── Rocky Linux 9 ──────────────────────────────────────────────
# 安装 lsyncd 和 inotify-tools
dnf install -y lsyncd inotify-tools

# ── Ubuntu 24.04 ───────────────────────────────────────────────
# 安装 lsyncd 和 inotify-tools
apt-get install -y lsyncd inotify-tools
```

```bash
# ── 以下命令两个系统相同 ────────────────────────────────────────
# 配置 node-01 到 node-02 的 SSH 免密（只在主节点 node-01 执行）
# [仅 node-01 执行]
ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519_openresty
ssh-copy-id -i /root/.ssh/id_ed25519_openresty.pub root@192.168.10.12

# 验证免密登录
ssh -i /root/.ssh/id_ed25519_openresty root@192.168.10.12 hostname
```

---

## 4. 生产级 nginx.conf 配置

> 主配置文件，**两台节点内容完全一致**（由 lsyncd 保持同步）。

```bash
cat > /etc/openresty/nginx.conf << 'NGINXEOF'
# ==============================================================
# OpenResty 生产级主配置文件
# 路径: /etc/openresty/nginx.conf
# ==============================================================

# ---------------------------------------------------------------
# worker 进程数：通常设为 CPU 核心数，auto 自动检测
# ---------------------------------------------------------------
worker_processes auto;

# worker 进程绑定 CPU（防止 CPU 切换开销）
worker_cpu_affinity auto;

# 全局错误日志
error_log /var/log/openresty/error.log warn;

# PID 文件
pid /var/run/openresty/nginx.pid;

# ---------------------------------------------------------------
# worker 打开的最大文件描述符数
# 系统级需同步配置: ulimit -n 65535
# ---------------------------------------------------------------
worker_rlimit_nofile 65535;

events {
    # 每个 worker 最大并发连接数（与 worker_rlimit_nofile 配合）
    worker_connections 65535;

    # 使用 epoll I/O 多路复用模型（Linux 平台最优选择）
    use epoll;

    # 允许 worker 一次接受多个新连接（高并发场景开启）
    multi_accept on;
}

http {
    # ---------------------------------------------------------------
    # 基础设置
    # ---------------------------------------------------------------
    include       mime.types;
    default_type  application/octet-stream;

    # 字符编码
    charset utf-8;

    # 隐藏 OpenResty/Nginx 版本信息（安全加固）
    server_tokens off;

    # ---------------------------------------------------------------
    # 日志格式（JSON 结构化日志，便于 ELK/Loki 收集）
    # ---------------------------------------------------------------
    log_format json_combined escape=json
        '{'
            '"time":"$time_iso8601",'
            '"remote_addr":"$remote_addr",'
            '"request":"$request",'
            '"status":"$status",'
            '"body_bytes_sent":"$body_bytes_sent",'
            '"request_time":"$request_time",'
            '"upstream_addr":"$upstream_addr",'
            '"upstream_response_time":"$upstream_response_time",'
            '"http_referer":"$http_referer",'
            '"http_user_agent":"$http_user_agent",'
            '"http_x_forwarded_for":"$http_x_forwarded_for"'
        '}';

    access_log /var/log/openresty/access.log json_combined buffer=32k flush=5s;

    # ---------------------------------------------------------------
    # 性能优化
    # ---------------------------------------------------------------
    # 零拷贝文件传输（静态文件性能提升 30%+）
    sendfile on;

    # 减少 TCP 包数量（与 sendfile 配合）
    tcp_nopush on;

    # 减少小数据包等待延迟
    tcp_nodelay on;

    # Keep-Alive 超时时间（秒）
    keepalive_timeout 65;

    # 单个 Keep-Alive 连接最多处理 1000 个请求
    keepalive_requests 1000;

    # ---------------------------------------------------------------
    # 客户端请求限制
    # ---------------------------------------------------------------
    # 客户端请求体最大大小（上传文件时需调整）
    client_max_body_size 100m;

    # 读取客户端请求头超时
    client_header_timeout 15s;

    # 读取客户端请求体超时
    client_body_timeout 30s;

    # 向客户端发送响应超时
    send_timeout 30s;

    # ---------------------------------------------------------------
    # Gzip 压缩（减少传输流量约 60%）
    # ---------------------------------------------------------------
    gzip on;
    gzip_min_length 1k;        # 小于 1KB 的响应不压缩
    gzip_comp_level 4;         # 压缩级别 1-9，4 是性能与压缩比的平衡点
    gzip_vary on;              # 添加 Vary: Accept-Encoding 响应头
    gzip_proxied any;          # 对代理请求也压缩
    gzip_types
        text/plain
        text/css
        text/javascript
        application/javascript
        application/json
        application/xml
        image/svg+xml;

    # ---------------------------------------------------------------
    # 限流（防刷、防 DDoS）
    # ---------------------------------------------------------------
    # 定义限流区域：按客户端 IP 限速，1MB 内存约存 16000 个 IP
    limit_req_zone $binary_remote_addr zone=api_rate:10m rate=100r/s;
    limit_req_zone $binary_remote_addr zone=login_rate:10m rate=5r/m;

    # 限流触发时返回 429（Too Many Requests）
    limit_req_status 429;

    # ---------------------------------------------------------------
    # 上游（后端服务）连接池
    # ---------------------------------------------------------------
    upstream backend_api {
        # 负载均衡策略：least_conn（最少连接）适合长连接场景
        least_conn;

        # ⚠️ 替换为实际后端服务 IP:Port
        server 192.168.10.21:8080 weight=5 max_fails=3 fail_timeout=30s;
        server 192.168.10.22:8080 weight=5 max_fails=3 fail_timeout=30s;
        server 192.168.10.23:8080 weight=3 max_fails=3 fail_timeout=30s backup;

        # 连接保活：复用 TCP 连接（显著降低后端延迟）
        keepalive 32;
        keepalive_requests 1000;
        keepalive_timeout 60s;
    }

    # ---------------------------------------------------------------
    # Lua 全局设置
    # ---------------------------------------------------------------
    # Lua 包路径（加入自定义 Lua 脚本目录）
    lua_package_path "/etc/openresty/lua/?.lua;/usr/local/openresty/lualib/?.lua;;";
    lua_package_cpath "/usr/local/openresty/lualib/?.so;;";

    # 共享内存字典（跨 worker 进程共享数据）
    lua_shared_dict rate_limit 10m;  # 限流计数器
    lua_shared_dict cache_dict  50m;  # 应用层缓存

    # Lua 代码缓存（生产环境必须开启，开发时可关闭）
    lua_code_cache on;

    # SSL 设置（如有 HTTPS）
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # ---------------------------------------------------------------
    # 引入虚拟主机配置
    # ---------------------------------------------------------------
    include /etc/openresty/conf.d/*.conf;
}
NGINXEOF
```

### 4.1 API 代理虚拟主机配置

```bash
cat > /etc/openresty/conf.d/api-proxy.conf << 'EOF'
# ==============================================================
# API 反向代理虚拟主机配置
# ==============================================================

# HTTP → HTTPS 强制跳转
server {
    listen 80;
    server_name api.yourcompany.com;  # ⚠️ 替换为实际域名

    # 安全响应头
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;

    # 强制 HTTPS 跳转
    return 301 https://$host$request_uri;
}

# HTTPS 主站
server {
    listen 443 ssl http2;
    server_name api.yourcompany.com;  # ⚠️ 替换为实际域名

    # TLS 证书（⚠️ 替换为实际证书路径）
    ssl_certificate     /etc/openresty/ssl/server.crt;
    ssl_certificate_key /etc/openresty/ssl/server.key;

    # 安全响应头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header X-XSS-Protection "1; mode=block" always;

    # 日志
    access_log /var/log/openresty/api-access.log json_combined;
    error_log  /var/log/openresty/api-error.log warn;

    # ---------------------------------------------------------------
    # Lua 鉴权（在请求到达后端前验证 Token）
    # ---------------------------------------------------------------
    access_by_lua_block {
        local auth = require("auth")
        auth.verify_token()
    }

    # ---------------------------------------------------------------
    # API 接口代理
    # ---------------------------------------------------------------
    location /api/ {
        # 应用限流（100 req/s，burst 允许突发 200 个，超出排队）
        limit_req zone=api_rate burst=200 nodelay;

        # 代理到后端
        proxy_pass http://backend_api;
        proxy_http_version 1.1;

        # 传递必要的请求头
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Keep-Alive（与 upstream keepalive 配合）
        proxy_set_header Connection "";

        # 代理超时设置
        proxy_connect_timeout  5s;   # 与后端建连超时
        proxy_send_timeout    30s;   # 向后端发送超时
        proxy_read_timeout    30s;   # 从后端读取超时

        # 缓冲设置（减少后端连接占用时间）
        proxy_buffering on;
        proxy_buffer_size 16k;
        proxy_buffers 8 16k;
    }

    # ---------------------------------------------------------------
    # 登录接口：严格限流
    # ---------------------------------------------------------------
    location /api/auth/login {
        limit_req zone=login_rate burst=10 nodelay;
        proxy_pass http://backend_api;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host            $host;
        proxy_set_header X-Real-IP       $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # ---------------------------------------------------------------
    # 健康检查接口（不鉴权、不限流）
    # ---------------------------------------------------------------
    location /health {
        access_log off;
        return 200 '{"status":"ok","node":"$hostname"}';
        add_header Content-Type application/json;
    }

    # ---------------------------------------------------------------
    # Nginx 状态接口（仅内网访问）
    # ---------------------------------------------------------------
    location /nginx_status {
        stub_status;
        allow 192.168.0.0/16;  # ⚠️ 仅允许内网访问
        deny all;
    }
}
EOF
```

---

## 5. Keepalived 高可用 VIP

### 5.1 安装 Keepalived（两台节点）

```bash
# ── Rocky Linux 9 ──────────────────────────────────────────────
dnf install -y keepalived

# ── Ubuntu 24.04 ───────────────────────────────────────────────
apt-get install -y keepalived
```

### 5.2 主节点配置（openresty-01）

```bash
cat > /etc/keepalived/keepalived.conf << 'EOF'
# ==============================================================
# Keepalived 配置 - 主节点 (openresty-01: 192.168.10.11)
# ==============================================================

global_defs {
    router_id openresty_01       # 节点标识，每台节点唯一
    # 检测脚本执行超时时间（秒）
    script_user root
    enable_script_security
}

# ---------------------------------------------------------------
# 健康检查脚本：检测 OpenResty 进程是否存活
# ---------------------------------------------------------------
vrrp_script chk_openresty {
    script "/bin/bash -c 'kill -0 $(cat /var/run/openresty/nginx.pid 2>/dev/null) 2>/dev/null'"
    interval 2      # 每 2 秒检测一次
    weight  -20     # 检测失败则优先级降低 20（触发 VIP 切换）
    fall    2       # 连续失败 2 次才判定为故障
    rise    2       # 连续成功 2 次才判定为恢复
}

vrrp_instance VI_OPENRESTY {
    state MASTER                  # 主节点：MASTER；备节点：BACKUP
    interface eth0                # ⚠️ 修改为实际网卡名（ip a 查看）
    virtual_router_id 61          # VRRP 组 ID，同组所有节点必须一致（1-255）
    priority 100                  # 主节点优先级（必须高于备节点）
    advert_int 1                  # VRRP 广播间隔（秒）

    # 认证（防止非法节点加入，两台节点配置相同）
    authentication {
        auth_type PASS
        auth_pass Openr3st@2026   # ⚠️ 修改为随机密码（最长 8 字符）
    }

    # 虚拟 IP（VIP）：客户端通过此 IP 访问服务
    virtual_ipaddress {
        192.168.10.100/24 dev eth0   # ⚠️ 修改为规划的 VIP 和实际网卡
    }

    # 绑定健康检查脚本
    track_script {
        chk_openresty
    }

    # VIP 切换时的通知脚本（可选，用于告警通知）
    # notify_master "/etc/keepalived/notify.sh MASTER"
    # notify_backup "/etc/keepalived/notify.sh BACKUP"
    # notify_fault  "/etc/keepalived/notify.sh FAULT"
}
EOF

systemctl enable keepalived --now
```

### 5.3 备节点配置（openresty-02）

```bash
cat > /etc/keepalived/keepalived.conf << 'EOF'
# ==============================================================
# Keepalived 配置 - 备节点 (openresty-02: 192.168.10.12)
# ==============================================================

global_defs {
    router_id openresty_02       # ⚠️ 注意：与主节点不同
    script_user root
    enable_script_security
}

vrrp_script chk_openresty {
    script "/bin/bash -c 'kill -0 $(cat /var/run/openresty/nginx.pid 2>/dev/null) 2>/dev/null'"
    interval 2
    weight  -20
    fall    2
    rise    2
}

vrrp_instance VI_OPENRESTY {
    state BACKUP                  # ⚠️ 备节点设为 BACKUP
    interface eth0                # ⚠️ 修改为实际网卡名
    virtual_router_id 61          # 必须与主节点一致
    priority 90                   # ⚠️ 备节点优先级必须低于主节点
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass Openr3st@2026   # ⚠️ 必须与主节点完全一致
    }

    virtual_ipaddress {
        192.168.10.100/24 dev eth0
    }

    track_script {
        chk_openresty
    }
}
EOF

systemctl enable keepalived --now
```

### 5.4 验证 VIP 切换

```bash
# 在主节点查看 VIP 是否挂载
ip addr show eth0 | grep "192.168.10.100"
# 正常输出应包含: inet 192.168.10.100/24

# 模拟主节点 OpenResty 故障，验证 VIP 漂移
systemctl stop openresty        # 在主节点执行
# 等待约 4 秒（2次检测失败 × 2秒间隔）

# 在备节点检查 VIP 是否漂移过来
ip addr show eth0 | grep "192.168.10.100"

# 恢复主节点
systemctl start openresty       # 在主节点执行
# VIP 会自动漂回主节点（因为主节点 priority 更高）
```

---

## 6. 配置实时同步方案（lsyncd）

### 6.1 lsyncd 简介

**lsyncd**（Live Syncing Daemon）基于 inotify 内核事件 + rsync 传输，实现目录的**实时同步**：

- 自动检测文件变更（create/modify/delete/move）
- 内置事件聚合，防止高频变更触发的 rsync 风暴
- 支持同步完成后执行回调命令（如触发 `openresty -s reload`）
- 开箱即用，无需编写 bash 脚本

### 6.2 lsyncd 配置（在主节点 openresty-01 上配置）

> **同步方向**：主节点 → 备节点（单向）。主节点为配置的 **唯一权威来源**（Source of Truth），所有配置修改在主节点进行，lsyncd 自动同步到备节点并触发 reload。

```bash
cat > /etc/lsyncd/lsyncd.conf.lua << 'EOF'
-- ==============================================================
-- lsyncd 配置文件
-- 路径: /etc/lsyncd/lsyncd.conf.lua
-- 语言: Lua
-- 说明: 监控 OpenResty 配置目录，实时同步到备节点，并触发 reload
-- ==============================================================

-- 日志配置
settings {
    logfile    = "/var/log/lsyncd/lsyncd.log",   -- lsyncd 自身日志
    statusFile = "/var/run/lsyncd/lsyncd.status", -- 状态文件
    statusInterval = 10,   -- 每 10 秒刷新一次状态文件
    nodaemon   = false,    -- 后台运行
    inotifyMode = "CloseWrite or Modify",  -- 触发事件类型
}

-- ==============================================================
-- 同步任务 1：同步 conf.d 目录（虚拟主机配置）
-- ==============================================================
sync {
    -- 使用 rsync over SSH 协议
    default.rsync,

    -- 监控的源目录（主节点）
    source = "/etc/openresty/conf.d/",

    -- 同步目标（备节点：IP + 目录）
    -- ⚠️ 替换 192.168.10.12 为实际备节点 IP
    target = "root@192.168.10.12:/etc/openresty/conf.d/",

    -- rsync 传输参数
    rsync = {
        archive  = true,       -- 等价于 -rlptgoD（保留权限、时间戳等）
        compress = false,      -- 内网传输无需压缩（压缩反而消耗 CPU）
        rsh      = "ssh -i /root/.ssh/id_ed25519_openresty -o StrictHostKeyChecking=no",
        -- 排除不需要同步的文件
        _extra   = {"--exclude=*.bak", "--exclude=*.tmp", "--exclude=*.swp"},
    },

    -- 延迟时间（秒）：事件发生后等待多少秒再同步（批量处理）
    -- 避免文件编辑过程中的多次触发
    delay = 3,

    -- 同步完成后在备节点执行的命令（触发配置热重载）
    -- 注意：onAttrib 处理权限变化；onCreate/onModify 处理内容变化
    on_action = {
        onCreate = [[
            /usr/bin/ssh -i /root/.ssh/id_ed25519_openresty root@192.168.10.12 \
                "/usr/bin/openresty -t && /usr/bin/openresty -s reload" \
                >> /var/log/lsyncd/reload.log 2>&1
        ]],
        onModify = [[
            /usr/bin/ssh -i /root/.ssh/id_ed25519_openresty root@192.168.10.12 \
                "/usr/bin/openresty -t && /usr/bin/openresty -s reload" \
                >> /var/log/lsyncd/reload.log 2>&1
        ]],
        onDelete = [[
            /usr/bin/ssh -i /root/.ssh/id_ed25519_openresty root@192.168.10.12 \
                "/usr/bin/openresty -t && /usr/bin/openresty -s reload" \
                >> /var/log/lsyncd/reload.log 2>&1
        ]],
    },
}

-- ==============================================================
-- 同步任务 2：同步 Lua 脚本目录
-- ==============================================================
sync {
    default.rsync,
    source = "/etc/openresty/lua/",
    target = "root@192.168.10.12:/etc/openresty/lua/",
    rsync = {
        archive  = true,
        compress = false,
        rsh      = "ssh -i /root/.ssh/id_ed25519_openresty -o StrictHostKeyChecking=no",
        _extra   = {"--exclude=*.bak", "--exclude=*.tmp"},
    },
    delay = 3,
    on_action = {
        onCreate = [[
            /usr/bin/ssh -i /root/.ssh/id_ed25519_openresty root@192.168.10.12 \
                "/usr/bin/openresty -t && /usr/bin/openresty -s reload" \
                >> /var/log/lsyncd/reload.log 2>&1
        ]],
        onModify = [[
            /usr/bin/ssh -i /root/.ssh/id_ed25519_openresty root@192.168.10.12 \
                "/usr/bin/openresty -t && /usr/bin/openresty -s reload" \
                >> /var/log/lsyncd/reload.log 2>&1
        ]],
    },
}

-- ==============================================================
-- 同步任务 3：同步 SSL 证书目录
-- ==============================================================
sync {
    default.rsync,
    source = "/etc/openresty/ssl/",
    target = "root@192.168.10.12:/etc/openresty/ssl/",
    rsync = {
        archive  = true,
        compress = false,
        rsh      = "ssh -i /root/.ssh/id_ed25519_openresty -o StrictHostKeyChecking=no",
    },
    delay = 5,   -- 证书变更等多 2 秒，确保文件完整写入
    on_action = {
        onModify = [[
            /usr/bin/ssh -i /root/.ssh/id_ed25519_openresty root@192.168.10.12 \
                "/usr/bin/openresty -t && /usr/bin/openresty -s reload" \
                >> /var/log/lsyncd/reload.log 2>&1
        ]],
    },
}
EOF

# 创建日志目录
mkdir -p /var/log/lsyncd /var/run/lsyncd

# 启用并启动 lsyncd
systemctl enable lsyncd --now

# 查看同步状态
cat /var/run/lsyncd/lsyncd.status
```

### 6.3 手动触发全量同步

```bash
# 手动全量同步（首次部署 or 备节点数据不一致时使用）
rsync -avz --delete \
    -e "ssh -i /root/.ssh/id_ed25519_openresty" \
    /etc/openresty/conf.d/ \
    root@192.168.10.12:/etc/openresty/conf.d/

rsync -avz --delete \
    -e "ssh -i /root/.ssh/id_ed25519_openresty" \
    /etc/openresty/lua/ \
    root@192.168.10.12:/etc/openresty/lua/

rsync -avz --delete \
    -e "ssh -i /root/.ssh/id_ed25519_openresty" \
    /etc/openresty/ssl/ \
    root@192.168.10.12:/etc/openresty/ssl/

# 触发备节点 reload
ssh -i /root/.ssh/id_ed25519_openresty root@192.168.10.12 \
    "openresty -t && openresty -s reload"
```

### 6.4 配置修改工作流

```
标准工作流程（只需操作主节点）：
─────────────────────────────────────────────────────────
1. 在主节点 (192.168.10.11) 编辑配置文件
   vim /etc/openresty/conf.d/api-proxy.conf

2. 语法检查
   openresty -t

3. 主节点热重载
   openresty -s reload

4. lsyncd 自动检测变更（约 3 秒延迟）
   → rsync 将修改推送到备节点
   → SSH 在备节点执行 openresty -t && openresty -s reload

5. 验证两台节点均已生效
   curl http://192.168.10.11/health
   curl http://192.168.10.12/health
─────────────────────────────────────────────────────────
```

---

## 7. Lua 扩展示例

### 7.1 JWT Token 鉴权模块

```bash
cat > /etc/openresty/lua/auth.lua << 'EOF'
-- ==============================================================
-- JWT Token 鉴权模块
-- 路径: /etc/openresty/lua/auth.lua
-- ==============================================================

local cjson = require("cjson.safe")
local ngx   = ngx

local _M = {}

-- 跳过鉴权的路径白名单
local white_list = {
    ["/health"] = true,
    ["/api/auth/login"] = true,
    ["/api/auth/refresh"] = true,
}

-- JWT 密钥（生产环境应从 Redis 或 Vault 获取，此处简化演示）
local JWT_SECRET = os.getenv("JWT_SECRET") or "your-production-secret-key"

-- Base64 URL 解码（JWT 使用 URL-safe Base64）
local function base64_decode(s)
    s = s:gsub("-", "+"):gsub("_", "/")
    local pad = 4 - (#s % 4)
    if pad ~= 4 then s = s .. string.rep("=", pad) end
    return ngx.decode_base64(s)
end

-- 验证 Token 主函数
function _M.verify_token()
    local uri = ngx.var.uri

    -- 白名单路径直接放行
    if white_list[uri] then
        return
    end

    -- 从 Authorization 请求头获取 Token
    local auth_header = ngx.req.get_headers()["Authorization"]
    if not auth_header then
        ngx.status = 401
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({code = 401, message = "Missing Authorization header"}))
        return ngx.exit(401)
    end

    -- 解析 Bearer Token
    local token = auth_header:match("^Bearer%s+(.+)$")
    if not token then
        ngx.status = 401
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({code = 401, message = "Invalid Authorization format"}))
        return ngx.exit(401)
    end

    -- 解析 JWT Payload（简化版，生产建议使用 lua-resty-jwt）
    local parts = {}
    for part in token:gmatch("[^.]+") do
        table.insert(parts, part)
    end

    if #parts ~= 3 then
        ngx.status = 401
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({code = 401, message = "Invalid token format"}))
        return ngx.exit(401)
    end

    -- 解码 Payload
    local payload_json = base64_decode(parts[2])
    local payload = cjson.decode(payload_json)

    if not payload then
        ngx.status = 401
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({code = 401, message = "Invalid token payload"}))
        return ngx.exit(401)
    end

    -- 检查过期时间
    if payload.exp and payload.exp < ngx.time() then
        ngx.status = 401
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({code = 401, message = "Token expired"}))
        return ngx.exit(401)
    end

    -- 将用户 ID 透传给后端
    ngx.req.set_header("X-User-ID", payload.sub or "")
    ngx.req.set_header("X-User-Role", payload.role or "")
end

return _M
EOF
```

---

## 8. 性能调优

### 8.1 系统内核参数

```bash
# 写入内核参数（所有节点执行）
cat > /etc/sysctl.d/99-openresty.conf << 'EOF'
# ==============================================================
# 针对 OpenResty 的内核参数调优
# ==============================================================

# --- 文件描述符 ---
# 系统级最大文件描述符数
fs.file-max = 1000000

# --- 网络连接 ---
# TCP 全连接队列长度（防止高并发时连接丢失）
net.core.somaxconn = 65535

# TCP 半连接（SYN）队列长度
net.ipv4.tcp_max_syn_backlog = 65535

# 网卡接收队列长度
net.core.netdev_max_backlog = 65535

# --- TCP 连接复用 ---
# 开启 TCP 连接时间等待快速回收（TIME_WAIT）
net.ipv4.tcp_tw_reuse = 1

# 允许 TIME_WAIT 端口复用（谨慎：可能影响 NAT 环境）
# net.ipv4.tcp_tw_recycle = 0  # Linux 4.12+ 已移除此参数

# TIME_WAIT 最多保留数量（超过则直接释放）
net.ipv4.tcp_max_tw_buckets = 200000

# --- TCP Keep-Alive ---
# 连接空闲多少秒后发送心跳包
net.ipv4.tcp_keepalive_time = 30
# 心跳包发送间隔（秒）
net.ipv4.tcp_keepalive_intvl = 10
# 心跳包失败次数后断开连接
net.ipv4.tcp_keepalive_probes = 3

# --- 缓冲区大小 ---
# TCP 接收缓冲区（最小/默认/最大 字节）
net.ipv4.tcp_rmem = 4096 87380 16777216
# TCP 发送缓冲区
net.ipv4.tcp_wmem = 4096 65536 16777216
# 系统级 socket 接收/发送缓冲区上限
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# --- 本地端口范围（反向代理需要大量出连接端口）---
net.ipv4.ip_local_port_range = 1024 65535
EOF

sysctl -p /etc/sysctl.d/99-openresty.conf
```

### 8.2 系统文件描述符限制

```bash
# 配置 OpenResty 进程的文件描述符上限
cat > /etc/security/limits.d/openresty.conf << 'EOF'
# OpenResty 进程文件描述符限制
*       soft    nofile  655360
*       hard    nofile  655360
root    soft    nofile  655360
root    hard    nofile  655360
EOF

# 重启 OpenResty 使配置生效
systemctl restart openresty
```

---

## 9. 监控接入

### 9.1 Prometheus 指标采集

```bash
# 安装 nginx-prometheus-exporter
docker run -d \
    --name openresty-exporter \
    --restart always \
    -p 9113:9113 \
    nginx/nginx-prometheus-exporter:latest \
    --nginx.scrape-uri=http://127.0.0.1:8080/nginx_status

# 在 prometheus.yml 中添加抓取配置
# - job_name: 'openresty'
#   static_configs:
#     - targets: ['192.168.10.11:9113', '192.168.10.12:9113']
```

### 9.2 Grafana 告警规则

```yaml
# 关键告警指标
# - openresty_http_connections{state="active"} > 10000  # 活跃连接数过高
# - rate(openresty_http_requests_total[5m]) < 10        # 请求量异常下降（可能故障）
# - openresty_up == 0                                   # 节点宕机
```

---

## 10. 日常运维

```bash
# ---------------------------------------------------------------
# 常用运维命令
# ---------------------------------------------------------------

# 检查配置语法（修改配置后必须先检查）
openresty -t

# 热重载（优雅重载，不中断现有连接）
openresty -s reload

# 查看 OpenResty 进程
ps aux | grep nginx

# 查看实时访问日志（JSON格式，用 jq 美化）
tail -f /var/log/openresty/access.log | jq .

# 查看错误日志
tail -f /var/log/openresty/error.log

# 查看 lsyncd 同步状态
cat /var/run/lsyncd/lsyncd.status

# 查看 lsyncd 日志
tail -f /var/log/lsyncd/lsyncd.log

# 查看 reload 触发记录
tail -f /var/log/lsyncd/reload.log

# 查看 Keepalived VIP 状态
ip addr show eth0 | grep "192.168.10.100"

# 查看 Keepalived 日志
journalctl -u keepalived -n 50 --no-pager
```

---

## 11. 常见问题排查

### 11.1 lsyncd 同步失败

```bash
# 现象：/var/log/lsyncd/lsyncd.log 报 SSH 连接失败
# 排查：
ssh -i /root/.ssh/id_ed25519_openresty root@192.168.10.12 hostname
# → 检查 SSH 免密是否正常

# 检查备节点 SSH 服务
systemctl status sshd
```

### 11.2 VIP 未漂移

```bash
# 查看 Keepalived 状态
systemctl status keepalived

# 检查 VRRP 日志
journalctl -u keepalived -n 50

# 检查两台节点 virtual_router_id 和 auth_pass 是否一致
grep -E "virtual_router_id|auth_pass" /etc/keepalived/keepalived.conf
```

### 11.3 502 Bad Gateway

```bash
# 查看上游连接状态
curl http://localhost:8080/nginx_status

# 检查后端服务是否可达
curl http://192.168.10.21:8080/health

# 查看错误日志
tail -100 /var/log/openresty/error.log | grep "upstream"
```

### 11.4 Lua 脚本调试

```bash
# 检查 Lua 语法
luac -p /etc/openresty/lua/auth.lua

# 临时开启 debug 日志（生产慎用）
# 在 nginx.conf 中修改：
# error_log /var/log/openresty/error.log debug;
# 然后 reload，查看日志
tail -f /var/log/openresty/error.log | grep lua
```
